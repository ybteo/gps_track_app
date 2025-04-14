import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:get/get.dart';
import 'package:gpsapp/constant/const.dart';
import 'package:gpsapp/constant/textstyle.dart';
import 'package:gpsapp/pages/history.dart';
import 'package:gpsapp/pages/homepage.dart';
import 'package:gpsapp/pages/profile.dart';

class BottomNaviBar extends StatefulWidget {
  final int initialIndex;
  const BottomNaviBar({super.key, this.initialIndex = 0});

  @override
  State<BottomNaviBar> createState() => _BottomNaviBarState();
}

class _BottomNaviBarState extends State<BottomNaviBar> {
  final NavigationController naviController = Get.put(NavigationController());

  @override
  void initState(){
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback((timeStamp) {
      naviController.selectedIndex.value = widget.initialIndex;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: Obx(
        () => NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: blue.shade300,
            indicatorColor: blue.shade50,
            labelTextStyle: MaterialStateProperty.resolveWith<TextStyle>(
              (states){
                if(states.contains(MaterialState.selected)){
                  return bodyXSBold.copyWith(color: blue.shade900);
                }
                return bodyXSSemibold;
              },
            ),
          ), 
          child: NavigationBar(
            height: 65,
            elevation: 5,
            selectedIndex: naviController.selectedIndex.value,
            onDestinationSelected: (index)=> naviController.selectedIndex.value = index,
            destinations: [
              NavigationDestination(
                icon: naviController.selectedIndex.value == 0? Icon(Icons.home, color: blue.shade300): Icon(Icons.home, color: grey.shade800), 
                label: 'Home',
              ),
              NavigationDestination(
                icon: naviController.selectedIndex.value == 1? Icon(Icons.access_time_filled, color: blue.shade300): Icon(Icons.access_time_filled, color: grey.shade800), 
                label: 'History',
              ),
              NavigationDestination(
                icon: naviController.selectedIndex.value == 2? Icon(Icons.account_circle, color: blue.shade300): Icon(Icons.account_circle, color: grey.shade800), 
                label: 'Profile',
              ),

            ],
          ),
        ),
      ),
      body: Obx(() => naviController.pages[naviController.selectedIndex.value]),


    );
  }
}

class NavigationController extends GetxController{
  final Rx<int> selectedIndex = 0.obs;
  final pages = [const Homepage(), const HistoryPage(), const ProfilePage()];
}