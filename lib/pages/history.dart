import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gpsapp/constant/const.dart';
import 'package:gpsapp/constant/textstyle.dart';
import 'package:gpsapp/pages/outside_record_page.dart';
import 'package:intl/intl.dart';

class HistoryPage extends StatefulWidget {
 
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final userEmail = FirebaseAuth.instance.currentUser?.email;

  void _showMessage(String message){
    if(mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: bodySBold),
        ),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    // final recordProvider = Provider.of<ClockInOutProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text('Attendance History', style: bodyXLBold),
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: blue.shade300,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              icon: const Icon(Icons.assignment_late_outlined, color: Colors.black, size: 25.0),
              onPressed: (){
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context)=> const OutsideRecordList()),
                );
              },
            ),
          ),
        ],
      ),


      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
                .collection('attendance_data')
                .doc(userEmail)
                .collection('attendance').orderBy('clockInTime', descending: true)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            print('StreamBuilder Error: ${snapshot.error}');
            return Center(
              child: Text('Error: ${snapshot.error}', style: bodyXLSemibold),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                children: [
                  const SizedBox(height: 70),
                  Icon(Icons.article_rounded, color: blue.shade400, size: 55),
                  Text('No attendance records found', style: bodyXLSemibold),
                ],
              ),
            );
          }

          final attendanceDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: attendanceDocs.length,
            itemBuilder: (context, index) {
              final data = attendanceDocs[index].data() as Map<String, dynamic>;
              final date = attendanceDocs[index].id;

              final Timestamp? clockInTimestamp = data['clockInTime'];
              final String clockInTime = clockInTimestamp != null
                  ? DateFormat('yyyy-MM-dd HH:mm:ss').format(clockInTimestamp.toDate())
                  : 'N/A';

              final Timestamp? clockOutTimestamp = data['clockOutTime'];
              final String clockOutTime = clockOutTimestamp != null
                  ? DateFormat('yyyy-MM-dd HH:mm:ss').format(clockOutTimestamp.toDate())
                  : 'N/A';
              final isInsideOffice = data['isInsideOffice'] ?? false;
              final bool? isinsideofficeClockout = clockOutTimestamp != null ? data['isInsideOffice_clockOut'] as bool? : null;
              // final isInsideOffice_clockOut = data['isInsideOffice_clockOut']?? false;

              final GeoPoint? geoPoint = data['clockIn_location'];
              final String location = geoPoint != null
                  ? '${geoPoint.latitude.toStringAsFixed(6)}, ${geoPoint.longitude.toStringAsFixed(6)}'
                  : 'Unknown';

              final GeoPoint? geopointOut = data['clockOut_location'];
              final String locationOut = geopointOut != null
                  ? '${geopointOut.latitude.toStringAsFixed(6)}, ${geopointOut.longitude.toStringAsFixed(6)}'
                  : 'Unknown';


              return Card(
                margin: const EdgeInsets.all(8),
                child: ListTile(
                  title: Text('Date: $date'),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Clock in at: $clockInTime'),
                      Text('At the office area (clock-in): ${isInsideOffice ? 'Yes' : 'No'}'),
                      Text('Location_clockIn: ${location.toString()}'),
                      Text('Clock out at: $clockOutTime'),
                      Text('At the office area (clock-out): ${isinsideofficeClockout == null? 'N/A' : (isinsideofficeClockout ? 'Yes' : 'No')}'),            
                      Text('Location_clockOut: ${locationOut.toString()}'),
                    ],
                  ),
                ),
              );
            },
          );

         
          

        },
      ),

      
    );

  }
}

