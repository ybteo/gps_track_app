class ClockInOutData{
  final DateTime recordDate;
  final DateTime clockInTime;
  final DateTime clockOutTime;
  final bool insideOffice;
  final String user;
 
  ClockInOutData({
    required this.recordDate,
    required this.clockInTime,
    required this.clockOutTime,
    required this.insideOffice,
    required this.user,
  });

  

  Map<String, dynamic>toJson()=>{
    'recordDate': recordDate.toIso8601String(),
    'clockInTime': clockInTime.toIso8601String(),
    'clockOutTime': clockOutTime.toIso8601String(),
    'insideOffice': insideOffice,
    'user':user,
  };

  factory ClockInOutData.fromJson(Map<String,dynamic> json) => ClockInOutData(
    recordDate: DateTime.parse(json['recordDate']), 
    clockInTime: DateTime.parse(json['clockInTime']), 
    clockOutTime: DateTime.parse(json['clockOutTime']), 
    insideOffice: json['insideOffice'] as bool,
    user: json['user'],
  );
}