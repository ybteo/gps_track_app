import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gpsapp/data%20model/clock_in_out_data.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ClockInOutProvider extends ChangeNotifier{
  List<ClockInOutData> clockInOutTimeList = [];
  List<ClockInOutData> get clockInOutList => clockInOutTimeList;

  String _currentDate = DateFormat('dd MMM yyyy').format(DateTime.now());
  Map<String, List<String>> _attendanceRecordsByDate = {};

  //get for today records
  List<String> get todayRecords => _attendanceRecordsByDate[_currentDate]?? [];

  //get records by date
  Map<String, List<String>> get attendanceRecordsByDate => _attendanceRecordsByDate;

  ClockInOutProvider(){
    loadRecords();
    refreshDailyRecords();
  }

  void addRecord(String record){
    if(_attendanceRecordsByDate[_currentDate] == null){
      _attendanceRecordsByDate[_currentDate] = [];
    }
    _attendanceRecordsByDate[_currentDate]!.add(record);
    saveRecord();
    notifyListeners();
  }

 void refreshDailyRecords(){
  String today = DateFormat('dd MMM yyyy').format(DateTime.now());
  if(_currentDate != today){
    _currentDate = today;
    if(!_attendanceRecordsByDate.containsKey(today)){
      _attendanceRecordsByDate[today]=[];
    }
    saveRecord();
    notifyListeners();
  }
 }

  void removeRecord(ClockInOutData recordList){
    clockInOutTimeList.remove(recordList);
    saveRecord();
    notifyListeners();
  }

  Future<void> saveRecord() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_attendanceRecordsByDate); // Convert to JSON string
    print('Saving JSON to SharedPreferences: $encoded'); // Debug saved data
    await prefs.setString('attendanceRecords', encoded);
  }


 Future<void> loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('attendanceRecords');
    
    if (data != null) {
      try {
        // Decode data and safely cast to Map<String, List<String>>
        final decodedData = jsonDecode(data);
        
        if (decodedData is Map<String, dynamic>) {
          _attendanceRecordsByDate = decodedData.map(
            (key, value) => MapEntry(
              key, 
              List<String>.from(value),
            ),
          );
        } else {
          print('Error: Decoded data is not a Map.');
          _attendanceRecordsByDate = {};
        }
      } catch (e) {
        print('Error loading records: $e');
        _attendanceRecordsByDate = {};
      }
    }
    notifyListeners();
  }


}