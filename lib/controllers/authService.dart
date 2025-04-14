import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gpsapp/pages/login.dart';
import 'package:gpsapp/widgets/bottomNaviBar.dart';

class AuthService extends StatelessWidget {
  AuthService({super.key});

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<void> restoreLoginState() async {
    String? token = await _secureStorage.read(key: 'auth_token');
    if(token != null){
      try{
        UserCredential userCredential = await _auth.signInWithCustomToken(token);
        if(userCredential.user !=null){
          debugPrint('User restored:${userCredential.user!.email}');
        }
      }catch(e){
        debugPrint('Error restoring login state: $e');
        await _secureStorage.delete(key: 'auth_token');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: restoreLoginState(), 
      builder: (context, snapshot) {
        if(snapshot.connectionState == ConnectionState.waiting){
          return const CircularProgressIndicator();
        }else{
          final user = _auth.currentUser;
          if(user != null){
            return const BottomNaviBar();
          }else{
            return const LoginPage();
          }
        }
      },
    );
  }
}