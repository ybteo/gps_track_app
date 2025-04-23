import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:gpsapp/constant/textstyle.dart';
import 'package:gpsapp/pages/homepage.dart';

class LoginAuth extends StatelessWidget {
  const LoginAuth({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if(snapshot.hasData){
            return const Homepage();
          }else{
            return SnackBar(
              content: Text('Invalid email or password.', style: bodyMSemibold)
            );
          }
      },),
    );
  }

  
}