import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:gpsapp/constant/const.dart';
import 'package:gpsapp/constant/textstyle.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart' as ll;

class OutsideRecordList extends StatefulWidget {
  const OutsideRecordList({super.key});

  @override
  State<OutsideRecordList> createState() => _OutsideRecordListState();
}

class _OutsideRecordListState extends State<OutsideRecordList> {

  
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  bool isOutsideOffice = false; //track user
  bool hasRecordedOutOfOffice = false; // Ensure `time_out_of_office_area` is recorded only once
  ll.LatLng officePoint = const ll.LatLng(3.129049576647911, 101.72164796642676);
  final userEmail = FirebaseAuth.instance.currentUser?.email;

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
    await flutterLocalNotificationsPlugin.show(0, 'Out of Office Area Alert', message, notificationDetails);
  }

  bool isWithinDistance(ll.LatLng userLocation){
    double distance = const ll.Distance().as(
      ll.LengthUnit.Meter, 
      officePoint, 
      userLocation,
    );
    return distance <= 50; // within 500m
  }


  @override
  Widget build(BuildContext context) {


    return Scaffold(
      appBar: AppBar(
        title: Text('Outside of Office Record', style: bodyLBold),
        centerTitle: true,
        backgroundColor: blue.shade100,
      ),

//only record the user that is outside the office
//record within clock in and out period
//record the location and time every 30 minutes if outside

      body: SingleChildScrollView(
        child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: fetchRecords(),
          builder: (context, snapshot){
            if(!snapshot.hasData){
              return const Center(
                child: CircularProgressIndicator(),
              );
            }
        
            final outOfOfficeEvents = snapshot.data!;
            return outOfOfficeEvents.isNotEmpty? 
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: outOfOfficeEvents.length,
                itemBuilder: (context, index){
                  final event = outOfOfficeEvents[index];
                  final time = (event['time'] as Timestamp).toDate();
                  final location = event['location'] as GeoPoint;
                  final eventType = event['eventType'];
              
                  return ListTile(
                    // title: Text('Date: ${DateFormat('yyyy-MM-dd').format(time)}', style: heading6Bold.copyWith(color: blue.shade900),),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Time: ${DateFormat('hh:mm:ss a').format(time)}', style: bodyLBold),
                        Text('Location: ${location.latitude}, ${location.longitude}', style: bodyLRegular),
                        Text('User is $eventType the office area.', style: bodyLRegular),             
                        Divider(thickness: 1, color: grey.shade500),
                      ],
                    ),
                  );
                }
              ) : Center(
                child: Text('No out of office events.', style: bodyXLBold),
              );
          }
        ),
      ),


    );
  }

  Stream<List<Map<String, dynamic>>> fetchRecords(){
    if(userEmail == null){
      return Stream.value([]); //return empty when no user logged in
    }

    String todayDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final CollectionReference outsideRef = FirebaseFirestore.instance
                                                .collection('attendance_data').doc(userEmail)
                                                .collection('events').doc(todayDate).collection('outside');
    final CollectionReference insideRef = FirebaseFirestore.instance
                                                .collection('attendance_data').doc(userEmail)
                                                .collection('events').doc(todayDate).collection('inside');

      return outsideRef.snapshots().asyncMap((outsideSnapshot) async {
        List<Map<String, dynamic>> allRecords = [];

        for(var record in outsideSnapshot.docs){
          allRecords.add({
            'eventType': 'outside',
            'time': record['time'],
            'location': record['location'],
          });
        }

//'inside' data
        QuerySnapshot insideSnapshot = await insideRef.get();
        for (var record in insideSnapshot.docs){
          allRecords.add({
            'eventType': 'inside',
            'time': record['time'],
            'location': record['location'],
          });
        }

        allRecords.sort((a,b)=> (b['time'] as Timestamp).compareTo(a['time'] as Timestamp));
        return allRecords;
      });
  }
}