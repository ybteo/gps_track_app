import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:geolocator/geolocator.dart';
import 'package:gpsapp/constant/const.dart';
import 'package:gpsapp/constant/textstyle.dart';
import 'package:gpsapp/controllers/clock_in_out_provider.dart';
import 'package:gpsapp/main.dart';
import 'package:gpsapp/widgets/button_style.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:location/location.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vpn_detector/vpn_detector.dart';
import 'package:workmanager/workmanager.dart';
import 'package:http/http.dart' as http;

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  DateTime currentTime = DateTime.now();
  late Timer _timer;
  double? radius = 50;//100;
  ll.LatLng officePoint = const ll.LatLng(3.129049576647911, 101.72164796642676);
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  List<String> attendanceRecords = [];

  bool hasUserClockedIn = false;
  Location location = Location();
  ll.LatLng? userLocation; //user's current location
  final MapController _mapController = MapController();

  Map<String, List<String>> attendanceRecordsByDate = {}; //key:date, value: records
  final db = FirebaseFirestore.instance;
  final userEmail = FirebaseAuth.instance.currentUser?.email;

  bool canClockIn = false;
  bool canClockOut = false;

  Timer? trackingTimer;
  bool isCurrentlyOutside = false;
  int outsideCount = 1;
  int insideCount = 1;
  bool isLoading = false;
  bool isFetchingLocation = false;

  //for record the gps, vpn and logout
  bool isLocationOn = true;
  bool isLogout = false; //after clock in
  bool isVpnOn = false;

  @override
  void initState(){
    super.initState();
    getUserCurrentLocation();
    initializeNotification();
    userLocationPin();
    backgroundLocationTracking();
    checkClockInStatus();
    checkVpnStatus();
    monitorSpecialEvents();
    Provider.of<ClockInOutProvider>(context, listen: false).refreshDailyRecords();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if(mounted){
        setState(() {
          currentTime = DateTime.now();
        });
      }
    });
  }


  Future<void> userLocationPin() async {
    final userLocation = await getUserCurrentLocation();
    if(userLocation != null){
      if(mounted){
        setState(() {
          this.userLocation = userLocation;
        });
      }
      _mapController.move(userLocation, 17);//to show user location pin
    }
  }


  //track normal location (gps)  //trigger the ip-based location when the gps is off
  Future<ll.LatLng?> getUserCurrentLocation() async {
    setState(() {
      isFetchingLocation = true;
    });

    try {
      // Check if GPS is enabled
      bool isGpsEnabled = await geo.Geolocator.isLocationServiceEnabled();
      if (!isGpsEnabled) {
        debugPrint('GPS is disabled. Attempting IP-based location.');
        isLocationOn = false;

        // Record the location_off event in Firebase
        int count = await getLatestCount('location_off');
        await recordEventsRecord(
          eventType: 'location_off',
          eventCount: count,
        );

        // Fetch IP-based location
        final ipLocation = await getLocationFromIp();
        if (ipLocation != null) {
          return ipLocation;
        } else {
          _showMessage('Failed to fetch IP-based location.');
          return null;
        }
      }

      // Fetch location using GPS
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      ).timeout(const Duration(seconds: 5), onTimeout: () {
        _showMessage('Location fetch timed out. Please try again by clicking the location icon.');
        throw Exception('Location fetch timed out.');
      });

      return ll.LatLng(position.latitude, position.longitude);
  } catch (e) {
    debugPrint('Error fetching location: $e');
    isLocationOn = false;

    // Record the location_off event in Firebase
    int count = await getLatestCount('location_off');
    await recordEventsRecord(
      eventType: 'location_off',
      eventCount: count,
    );

    // Fetch IP-based location as a fallback
    final ipLocation = await getLocationFromIp();
    if (ipLocation != null) {
      return ipLocation;
    } else {
      _showMessage('Failed to fetch location using IP.');
      return null;
    }
  } finally {
    if(mounted){
      setState(() {
        isFetchingLocation = false;
      });
    }
  }
}

  //calculate distance
  bool isWithinDistance(ll.LatLng userLocation){
    double distance = const ll.Distance().as(
      ll.LengthUnit.Meter, 
      officePoint, 
      userLocation,
    );
    return distance <= 50; // within 500m
  }


  //if the gps is off, then use this alternative way 
  Future<geo.Position?> getGeoLocation() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if(!serviceEnabled){
      final ipLocation = await getLocationFromIp();

      if(ipLocation != null){ 
          return Position(
            latitude: ipLocation.latitude,
            longitude: ipLocation.longitude,
            timestamp: DateTime.now(),
            headingAccuracy: 0,
            altitudeAccuracy: 0,
            heading: 0,
            speed: 0,
            speedAccuracy: 0, 
            accuracy: 0, 
            altitude: 0,
          );
        
      }
      _showMessage('Location services are disabled and IP-based location failed.');
    }

    bool isGpsEnabled = await geo.Geolocator.isLocationServiceEnabled();
    geo.LocationAccuracy accuracy = isGpsEnabled? geo.LocationAccuracy.high : geo.LocationAccuracy.low;

    Position position = await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: accuracy, //for wifi or cellular 
    );

    return position; 
  }



//IP-based location
  Future<ll.LatLng?> getLocationFromIp() async {
    try {

      //API requires Pro Plan – The free version may not allow programmatic access.
      final response = await http.get(Uri.parse('http://ip-api.com/json/')); //if add http/s then will be failed to fetch

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data.containsKey('lat') && data.containsKey('lon')) {
          ll.LatLng ipLocation = ll.LatLng(data['lat'], data['lon']);

          ll.LatLng adjustedLocation = adjustCoordinates(ipLocation, 500, 4300);
          print("IP-Based Location Fetched: ${adjustedLocation.latitude}, ${adjustedLocation.longitude}");

          return adjustedLocation;
        } else {
          print("Failed to parse IP location data.");
        }
      } else {
        print("IP location API request failed with status: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching IP-based location: $e");
    }

    _showMessage('Failed to fetch IP-based location.');
    return null;
  }


  //distance-based adjustment  -- adjust the ip-based location
  //need to apply in the getLocationFromIp function
  ll.LatLng adjustCoordinates(ll.LatLng original, double shiftLatMeters, double shiftLngMeters){
    const double latDegreeToMeters = 111000; //1 lat = approximately 111km
    double newLat = original.latitude + (shiftLatMeters/latDegreeToMeters);
    double newLng = original.longitude + (shiftLngMeters/(latDegreeToMeters * cos(original.latitude * pi/180)));
    
    return ll.LatLng(newLat, newLng);
  }


//wifi/cellular to detect location?
  Future<geo.Position?> getWifiLocation() async {
    try{
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.low,
      );
      return position;
    }catch(e){
      _showMessage('Error: $e');
      return null;
    }
  }

  //monitor location within the area, for workmanager
  void backgroundLocationTracking() async {
    LocationPermission permission = await Geolocator.requestPermission();
    if(permission == LocationPermission.denied || permission == LocationPermission.deniedForever){
      print('Location permission denied.');
      return;
    }

    Workmanager().initialize(callbackDispatcher, isInDebugMode: true);

    Workmanager().registerPeriodicTask(
      "restartTrackingTask", 
      "restartTracking",
      frequency: const Duration(minutes: 10),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected, requiresBatteryNotLow: true),
    );
  }

  Future<void> checkClockInStatus() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      hasUserClockedIn = prefs.getBool('isClockedIn')?? false;
    });

    if(hasUserClockedIn){
      startBackgroundTracking();
    }
  }

  void startBackgroundTracking(){
    FlutterBackgroundService().startService();
  }

  void stopBackgroundTracking(){
    FlutterBackgroundService().invoke("StopTracking");
  }

  void monitorSpecialEvents(){
    Timer.periodic(const Duration(minutes: 5), (timer) async {
      await checkLocationOff();
      await checkLogout();
      await checkVpnStatus();
    });
  }

  //check vpn status
  Future<void> checkVpnStatus() async {
    bool vpnStatus = await VpnDetector().isVpnActive();

    if(vpnStatus != isVpnOn){
      isVpnOn = vpnStatus;

      int count = await getLatestCount('vpn');
      await recordEventsRecord(
        eventType: 'vpn', 
        eventCount: count,
      );
    }
  }

  //detect the user log out after clock in
  Future<void> checkLogout() async {
    if(hasUserClockedIn && FirebaseAuth.instance.currentUser == null){
      isLogout = true;

      int count = await getLatestCount('logout');
      await recordEventsRecord(
        eventType: 'logout', 
        eventCount: count,
      );
      
    }
  }

  //detect the user on or off location
  Future<void> checkLocationOff() async {
    bool gpsON = await geo.Geolocator.isLocationServiceEnabled();

    if(gpsON != isLocationOn){
      isLocationOn = gpsON;

      if(!gpsON){
        int count = await getLatestCount('location_off');
        await recordEventsRecord(
          eventType: 'location_off', 
          eventCount: count,
        );
      }
    }
  }

//record the special events(vpn, location, logout)
  Future<void> recordEventsRecord({
    // required DateTime time,
    required String eventType,
    required int eventCount,
  }) async {
    if(userEmail == null) return;

    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    DateTime now = DateTime.now();
    final String docId = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';

      final CollectionReference eventCollection = firestore
                          .collection('attendance_data').doc(userEmail)
                          .collection('events').doc(docId)
                          .collection(eventType);

      final DocumentReference specialEvent = eventCollection.doc('${eventType}_$eventCount');

    try{
      await specialEvent.set({
        'time': Timestamp.fromDate(now),

      },SetOptions(merge: true)).then((_) {
        _showMessage('$eventType event is recorded.');

      });
    }catch(e){
        _showMessage('Failed to record $eventType event: $e');
    };
  }


  Future<int> getLatestCount(String eventType) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    if(userEmail == null) return 1;
    DateTime now = DateTime.now();
    final String docId = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    final CollectionReference eventCollection = firestore.collection('attendance_data').doc(userEmail)
                                                .collection('events').doc(docId).collection(eventType);

    QuerySnapshot querySnapshot = await eventCollection.get();
    return querySnapshot.docs.length +1;
  }


//Firebase for the attendance list (clock-in and out)
  Future<void> saveDataIntoFirestore({
    required DateTime clockInTime,
    DateTime? clockOutTime,
    required bool isInsideOffice,
    bool? isInsideOffice_clockOut,
    required double clockInLatitude,
    required double clockInLongitude,
    double? clockOutLatitude,
    double? clockOutLongitude,
  }) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final userEmail =FirebaseAuth.instance.currentUser;

    if(userEmail == null){
      _showMessage('The user is not existed.');
      return;
    }
    
    final DocumentReference attendanceDoc = firestore
                  .collection('attendance_data')
                  .doc(userEmail.email)
                  .collection('attendance')
                  .doc('${clockInTime.year}-${clockInTime.month.toString().padLeft(2,'0')}-${clockInTime.day.toString().padLeft(2,'0')}');
    
    await attendanceDoc.set({
      'clockInTime':Timestamp.fromDate(clockInTime),
      'clockOutTime':clockOutTime != null ? Timestamp.fromDate(clockOutTime):null,
      'isInsideOffice':isInsideOffice,
      'isInsideOffice_clockOut': isInsideOffice_clockOut,
      'clockIn_location': GeoPoint(clockInLatitude, clockInLongitude),

      if(clockOutLatitude != null && clockOutLongitude != null)
      'clockOut_location': GeoPoint(clockOutLatitude, clockOutLongitude),
    }, SetOptions(merge: true));
  }


//record for the outside of the area record, set to record every 30 minits when user is outside. Once inside, then just record one time
  Future<void> recordOutOfOfficeEvent({
    required DateTime timeOut,
    required double latitudeOut,
    required double longitudeOut,
    required String eventType,  //inside or outside
    required int eventCount,
    DateTime? timeIn,
  }) async {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      
      if(userEmail == null){
        _showMessage('The user is not logged in.');
        return;
      }

      final String docId = '${timeOut.year}-${timeOut.month.toString().padLeft(2,'0')}-${timeOut.day.toString().padLeft(2,'0')}';

      final CollectionReference eventCollection = firestore
                          .collection('attendance_data').doc(userEmail)
                          .collection('events').doc(docId)
                          .collection(eventType);

      final DocumentReference outOfOffice = eventCollection.doc('${eventType}_$eventCount');

    try{
      await outOfOffice.set({
        'time': Timestamp.fromDate(timeOut),
        'location': GeoPoint(latitudeOut, longitudeOut),
      
      },SetOptions(merge: true)).then((_) {
        _showMessage('$eventType event is recorded.');

      });
    }catch(e){
        _showMessage('Failed to record $eventType event: $e');
    };
    
  }

  

  void _showMessage(String message){
    if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: bodySBold),
        ),
      );
    }
  }


  //notifications of alert 
  void initializeNotification(){
    AndroidInitializationSettings initializationSettingsAndroid = const AndroidInitializationSettings('@mipmap/ic_launcher');
    InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  Future<void> sendNotification(String message) async {
    AndroidNotificationDetails androidDetails = const AndroidNotificationDetails(
      'channelId', 'channelName',
      importance: Importance.high, 
      priority: Priority.high
    );
    NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.show(0, 'Attendance Alert', message, notificationDetails);
  }

    Future<void> onClockIn() async {
      setState(() {
        isLoading = true;
      });

      final userLocation = await getUserCurrentLocation();
      if(userLocation != null){
        bool isInside = isWithinDistance(userLocation);
        await saveDataIntoFirestore(
          clockInTime: DateTime.now(), 
          isInsideOffice: isInside, 
          clockInLatitude: userLocation.latitude, 
          clockInLongitude: userLocation.longitude,
        );

        if(!isInside){
          final int eventCount = await getLatestCount('outside');
          await recordOutOfOfficeEvent(
            timeOut: DateTime.now(), 
            latitudeOut: userLocation.latitude, 
            longitudeOut: userLocation.longitude, 
            eventType: 'outside', 
            eventCount: eventCount
          );
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isClockedIn', true);

        startBackgroundTracking();

        Workmanager().registerPeriodicTask(
          "backgroundLocationTask", 
          "fetchAndStoreLocation",
          frequency: const Duration(minutes: 10),
          existingWorkPolicy: ExistingWorkPolicy.keep,
          constraints: Constraints(networkType: NetworkType.connected, requiresBatteryNotLow: true),
        );

        setState(() {
          attendanceRecords.add(
            'Clock in at ${DateFormat('hh:mm:ss a').format(DateTime.now())}, you are ${isInside ? 'inside' : 'outside'} of the office area.'
          );
          hasUserClockedIn = true;
          canClockIn = false;
          canClockOut = true;
        });
        _showMessage('Clock-in successful.');
      }
      setState(() {
        isLoading = false;
      });
    }

    Future<void> onClockOut() async {
      setState(() {
        isLoading = true;
      });

      final userLocation = await getUserCurrentLocation(); // Avoid duplicate calls
      if (userLocation != null) {
        final isInside = isWithinDistance(userLocation);

        final user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          _showMessage('User not logged in.');
          return;
        }

        final docId = DateTime.now().toIso8601String().substring(0, 10);
        final attendanceDoc = FirebaseFirestore.instance
            .collection('attendance_data')
            .doc(user.email)
            .collection('attendance')
            .doc(docId);

        await attendanceDoc.update({
          'clockOutTime': Timestamp.fromDate(DateTime.now()),
          'isInsideOffice_clockOut': isInside,
          'clockOut_location': GeoPoint(userLocation.latitude, userLocation.longitude),
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isClockedIn', false);

        stopBackgroundTracking();

        setState(() {
          hasUserClockedIn = false;
          canClockIn = true;
          canClockOut = false;
        });
        _showMessage('Clock-out successful.');

      }
      setState(() {
        isLoading = false;
      });
    }


  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    String? lastRecord = attendanceRecords.isNotEmpty? attendanceRecords.last : null;
    bool canClockIn = lastRecord == null || lastRecord.contains('Clock-out');
    //bool canClockOut = lastRecord !=null && lastRecord.contains('Clock-in');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text("Attendance GPS", style: bodyXLBold),
        centerTitle: true,
        backgroundColor: blue.shade300,
      ),
      
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              //display the current date time
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadiusDirectional.circular(8),
                  color: blue.shade100,
                ),
                width: 300,
                child: Text(DateFormat('hh:mm:ss a').format(currentTime), style: heading1Bold.copyWith(color: blue), textAlign: TextAlign.center,),
              ),
              const SizedBox(height: 15),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadiusDirectional.circular(8),
                  color: grey,
                ),
                width: 150,
                child: Text(DateFormat('dd MMM yyyy').format(currentTime), style: heading5Bold.copyWith(color: blue.shade300), textAlign: TextAlign.center,),
              ),
              
              const SizedBox(height: 35),

              Stack(
                children: [
                  SizedBox(
                    height: 350,
                    width: 500,
                    child: FlutterMap(
                      mapController: _mapController,
                      options: const MapOptions(
                        initialZoom: 17,
                        initialCenter: ll.LatLng(3.129049576647911, 101.72164796642676),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        ),
                            
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: const ll.LatLng(3.129049576647911, 101.72164796642676), //this is office location
                              radius: radius ?? 50, 
                              color: blue.shade300.withOpacity(0.15),
                              borderColor: blue.shade900,
                              borderStrokeWidth: 2.5,
                              useRadiusInMeter: true,
                            ),
                          ],
                        ),
                            
                        MarkerLayer(
                          markers: [
                            if (userLocation != null)
                              Marker(
                                height: 70,
                                width: 70,
                                point: userLocation!,
                                child: Column(
                                  children: [
                                    Icon(Icons.location_pin, color: blue.shade600, size: 35),
                                    Text(
                                      'You are here!',
                                      style: bodyXSSemibold.copyWith(color: blue.shade600, fontSize: 10),
                                    ),
                                  ],
                                ),
                              )
                            else
                              Marker(
                                height: 55,
                                width: 35,
                                point: const ll.LatLng(3.129049576647911, 101.72164796642676),
                                child: Column(
                                  children: [
                                    Icon(Icons.location_off, color: blue.shade600, size: 25),
                                    Text(
                                      'Location off',
                                      style: bodyXSSemibold.copyWith(color: blue.shade600, fontSize: 8),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),


                      ],
                    ),
                  ),

                  if(isFetchingLocation)
                  Positioned.fill(
                    top: 100,
                    bottom: 100,
                    right: 100,
                    left: 100,
                    child: Container(
                      color: Colors.transparent,
                      child: CircularProgressIndicator(
                        color: blue.shade400, 
                        strokeWidth: 10,
                        backgroundColor: grey.shade600,
                
                      ),
                    ),
                  ),

                  //re-center button and refresh location state
                  Positioned(
                    bottom: 15, right: 15,
                    child: FloatingActionButton(
                      mini: true,
                      backgroundColor: Colors.white,
                      onPressed: () async {
                        if(userLocation != null){
                          _mapController.move(
                            userLocation!, 
                            17,
                          );
                        } else {
                          _showMessage('Fetching the latest location...');
                          final newLocation = await getUserCurrentLocation();

                          if(newLocation != null){
                            setState(() {
                              userLocation = newLocation;
                            });
                            _mapController.move(newLocation, 17);
                          }else{
                            _showMessage('Failed to fetch location. Please try again by clicking the location icon.');
                          }
                        }
                      },

                      child: Icon(Icons.my_location_outlined, color: blue.shade500),
                    ),
                  ),

                  
                ],
              ),  
          

              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Clock-in Button
                  LightBlueButton(
                    onPressed: isLoading || canClockIn
                        ? () async {
                            await onClockIn();
                          }
                        : () {
                            _showMessage('You have already clocked in.');
                          },
                    text: 'Clock-in',
                  ),

                  const SizedBox(width: 30),

                  // Clock-out Button
                  LightBlueButton(
                    onPressed: canClockOut || isLoading
                        ? () async {
                            await onClockOut();
                          }
                        : () {
                            _showMessage('You have already clocked out.');
                          },
                    text: 'Clock-out',
                  ),
                ],
              ),
          
              const SizedBox(height: 30),

              if(isLoading)
                Center(
                  child: CircularProgressIndicator(color: blue.shade600),
                ),

              if(isLoading)
              const SizedBox(height: 30),

//refresh the record everyday, save the date record at the history page
//fetch data from firestore
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                      .collection('attendance_data').doc(userEmail)
                      .collection('attendance')
                      .where('clockInTime', isGreaterThanOrEqualTo: DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) // Filter today's records
                      .orderBy('clockInTime', descending: true)
                      .snapshots(), 
              builder: (context, snapshot){
                if(!snapshot.hasData){
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final attendanceRecords = snapshot.data!.docs;
                if(attendanceRecords.isNotEmpty){
                  final latestRecord = attendanceRecords.first.data() as Map<String, dynamic>;
                  final clockInTime = (latestRecord['clockInTime'] as Timestamp?)?.toDate();
                  final clockOutTime = (latestRecord['clockOutTime'] as Timestamp?)?.toDate();

                  WidgetsBinding.instance.addPostFrameCallback((_){
                    if(clockInTime != null && clockOutTime == null){
                      setState(() {
                        hasUserClockedIn = true;
                        canClockOut = true;
                        canClockIn = false;
                      });
                    }else{
                      setState(() {
                        hasUserClockedIn = false;
                        canClockOut = false;
                        canClockIn = true;
                      });
                    }
                  });

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Attendance Records (${DateFormat('dd MMM yyyy').format(DateTime.now())})', style: heading5Bold),
                        
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: attendanceRecords.length,
                        itemBuilder: (context, index){
                          final record = attendanceRecords[index].data() as Map<String, dynamic>;
                          final clockInTime = (record['clockInTime'] as Timestamp?)?.toDate();
                          final clockOutTime = (record['clockOutTime'] as Timestamp?)?.toDate();
                          final isInsideOffice = record['isInsideOffice'] ?? false;
                          final isInsideOfficeClockOut = record['isInsideOffice_clockOut'] ?? false;

                          return ListTile(
                            //leading: Icon(Icons.access_time, color: blue),
                            title: Column(
                              children: [
                                if(clockInTime != null)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: [
                                    Icon(Icons.access_time, color: blue),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Clock-in: ${DateFormat('hh:mm:ss a').format(clockInTime)}, you were ${isInsideOffice ? 'inside' : 'outside'} the office.', 
                                            maxLines: 2, overflow: TextOverflow.ellipsis
                                      ),
                                    ),
                                    //add if location off/ vpn on?
                                  ],
                                ),

                                if(clockOutTime != null)
                                Row(
                                  children: [
                                    Icon(Icons.access_time, color: blue),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Clock-out: ${DateFormat('hh:mm:ss a').format(clockOutTime)}, you were ${isInsideOfficeClockOut ? 'inside' : 'outside'} the office.',
                                            maxLines: 2, overflow: TextOverflow.ellipsis
                                      ),
                                    ),
                                    //add if location off/ vpn on?


                                  ],
                                ),
                              ],

                            ),
                          );
                        }
                      ),

                    ],  
                  );
                } return Center(
                  child: Text('No attendance records for today.', style: bodyLBold),
                );
                
              }
            ),


            ], //outside record at other page
          
          
          ),
        ),
      ),
    );
  }
  
}