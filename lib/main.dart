import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:geolocator/geolocator.dart'as geo;
import 'package:gpsapp/controllers/authService.dart';
import 'package:gpsapp/controllers/clockInOutProvider.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'firebase_options.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, //added after the firebase connected
  );

//for flutter_background_service , for app is killed case
  await initializeBackgroundService();

  final prefs = await SharedPreferences.getInstance();
  bool isClockedIn = prefs.getBool('isClockedIn')?? false;

  if(isClockedIn){
    FlutterBackgroundService().startService();
    //----------------------------------------------------------------------------------------

      Workmanager().initialize(callbackDispatcher, isInDebugMode: true);//this is workmanager
      Workmanager().registerPeriodicTask(
      "backgroundLocationTask",
      "fetchAndStoreLocation",
      frequency: const Duration(minutes: 10),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_)=> ClockInOutProvider()),
      ],
      child: const MyApp(),
    ),
  );
}


  bool isWithinDistance(ll.LatLng userLocation){
    ll.LatLng officePoint = const ll.LatLng(3.129049576647911, 101.72164796642676); //can reset
    
      double distance = const ll.Distance().as(
        ll.LengthUnit.Meter, 
        officePoint, 
        userLocation,
      );
      return distance <= 50; // within 500m //can reset
  }


  Future<void> initializeBackgroundService() async {
    final service = FlutterBackgroundService();

    await service.configure(

      iosConfiguration: IosConfiguration(), 

      androidConfiguration: AndroidConfiguration(
        onStart: onStart, 
        isForegroundMode: true,
        autoStart: true,
      ),
    );

    service.startService();
  }

  void onStart(ServiceInstance service) async {
    WidgetsFlutterBinding.ensureInitialized();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    

    if(service is AndroidServiceInstance){
      service.setAsForegroundService();
    }

    Timer.periodic(const Duration(minutes: 10), (timer) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      bool isClockedIn = prefs.getBool('isClockedIn')?? false;

      if(isClockedIn){

        // FlutterBackgroundService().startService();

        geo.Position? position = await getUserLocation();
        if(position != null){
          debugPrint('User location: ${position.latitude}, ${position.longitude}');
          bool isInside = isWithinDistance(ll.LatLng(position.latitude, position.longitude));

            if(!isInside){
              final int eventCount = await getLatestCount('outside');
              await recordOutOfOfficeEvent(
                timeOut: DateTime.now(), 
                latitudeOut: position.latitude, 
                longitudeOut: position.longitude, 
                eventType: 'outside', 
                eventCount: eventCount
              );
            }
        }
      }
    });
  }

  Future<geo.Position?> getUserLocation() async {
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      return await getLocationFromIp();
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied || permission == geo.LocationPermission.deniedForever) {  
      permission = await geo.Geolocator.requestPermission();
      if(permission == geo.LocationPermission.denied || permission == geo.LocationPermission.deniedForever){
          return await getLocationFromIp();
      }
     
    }

    return await geo.Geolocator.getCurrentPosition(
      desiredAccuracy: geo.LocationAccuracy.bestForNavigation,
    );
  }

//when location off
  Future<geo.Position?> getLocationFromIp() async {
    try {
      final response = await http.get(Uri.parse('https://ipinfo.io/json'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final locString = data['loc'];

        if (locString != null) {
          final coords = locString.split(',');
          final lat = double.tryParse(coords[0]);
          final lng = double.tryParse(coords[1]);

          if (lat != null && lng != null) {
            return geo.Position(
              latitude: lat,
              longitude: lng,
              timestamp: DateTime.now(),
              accuracy: 0,
              altitude: 0,
              heading: 0,
              speed: 0,
              speedAccuracy: 0,
              altitudeAccuracy: 0,
              headingAccuracy: 0,
            );
          }
        }
      }
    } catch (e) {
      print('Error fetching IP-based location: $e');
    }
    return null;
  }
  
  
  Future<int> getLatestCount(String eventType) async {
      WidgetsFlutterBinding.ensureInitialized();
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final userEmail = FirebaseAuth.instance.currentUser?.email;

    if(userEmail == null) return 1;
    DateTime now = DateTime.now();
    final String docId = '${now.year}-${now.month.toString().padLeft(2,'0')}-${now.day.toString().padLeft(2,'0')}';
    final CollectionReference eventCollection = firestore.collection('attendance_data').doc(userEmail)
                                                .collection('events').doc(docId).collection(eventType);

    QuerySnapshot querySnapshot = await eventCollection.get();
    return querySnapshot.docs.length +1;
  }

    //for the function in the homepage
    @pragma('vm:entry-point')
    void callbackDispatcher(){ 

      Workmanager().executeTask((task, inputData) async {

        WidgetsFlutterBinding.ensureInitialized();
        await Firebase.initializeApp();
        // final location = await getUserLocation();
        if(task == "fetchAndStoreLocation"){
          final prefs = await SharedPreferences.getInstance();
          bool isClockedIn = prefs.getBool('isClockedIn')?? false;

          if(isClockedIn){
            FlutterBackgroundService().startService();
          }
        }

        return Future.value(true);
       /*  WidgetsFlutterBinding.ensureInitialized();
        await Firebase.initializeApp();

        // Get the current location
          try {
            geo.Position position = await geo.Geolocator.getCurrentPosition(
              desiredAccuracy: geo.LocationAccuracy.high,
            );
            bool isInside = isWithinDistance(ll.LatLng(position.latitude, position.longitude));

            if(!isInside){
              final int eventCount = await getLatestCount('outside');
              await recordOutOfOfficeEvent(
                timeOut: DateTime.now(), 
                latitudeOut: position.latitude, 
                longitudeOut: position.longitude, 
                eventType: 'outside', 
                eventCount: eventCount
              );
            }else{
              final int eventCount = await getLatestCount('inside');
              await recordOutOfOfficeEvent(
                timeOut: DateTime.now(), 
                latitudeOut: position.latitude, 
                longitudeOut: position.longitude, 
                eventType: 'inside', 
                eventCount: eventCount
              );
            }
            return Future.value(true);

          } catch (e) {
            print("Error getting location: $e");
            return Future.value(false);
          } */
        });
    }

Future<void> recordOutOfOfficeEvent({
    required DateTime timeOut,
    required double latitudeOut,
    required double longitudeOut,
    required String eventType,  //inside or outside
    required int eventCount,
    // DateTime? timeIn,
  }) async {
      final FirebaseFirestore firestore = FirebaseFirestore.instance;
      final userEmail = FirebaseAuth.instance.currentUser?.email;

      if(userEmail == null){
        debugPrint('The user is not logged in.');
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
        debugPrint('$eventType event is recorded.');

      });
    }catch(e){
        debugPrint('Failed to record $eventType event: $e');
    };
    
  }


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GPS locate app',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
      ),
      home: AuthService(),
    );
  }
}





