import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceDataList{
  final DateTime clockInTime;
  final DateTime clockOutTime;
  final bool insideArea;
  final GeoPoint location;

  AttendanceDataList({
    required this.clockInTime,
    required this.clockOutTime,
    required this.location,
    required this.insideArea,
  });

  Map<String, dynamic> toJson()=> {
    'clockInTime': clockInTime,
    'clockOutTime': clockOutTime,
    'location': location,
    'insideArea': insideArea,
  };

//map data fetched from firestore to here

  factory AttendanceDataList.fromJson(Map<String, dynamic>json) => AttendanceDataList(
    clockInTime: json['clockInTime'], 
    clockOutTime: json['clockOutTime'],
    location: json['location'],
    insideArea: json['isInsideOffice'],
  );
}