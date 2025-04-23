import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gpsapp/constant/const.dart';
import 'package:gpsapp/constant/textstyle.dart';
import 'package:gpsapp/pages/login.dart';
import 'package:gpsapp/widgets/button_style.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  final userEmail = FirebaseAuth.instance.currentUser?.email;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  @override
  void initState(){
    super.initState();
    restoreLoginState();
  }

  Future<void> storeUserToken() async {
    User? user = _auth.currentUser;
    if(user != null){
      String? token = await user.getIdToken();
      if(token != null){
        await _secureStorage.write(key: 'auth_token', value: token);
      }
    }
  }

  Future<void> restoreLoginState() async {
    String? token = await _secureStorage.read(key: 'auth_key');
    if(token != null){
      try{
        UserCredential userCredential = await _auth.signInWithCustomToken(token);
        if(userCredential.user != null){
          debugPrint('User restored: ${userCredential.user!.email}');
        }
      }catch(e){
          await _secureStorage.delete(key: 'auth_token');
      }
    }
  }

  Future<void> logout() async {
    try{
      await _auth.signOut();
      await _secureStorage.delete(key: 'auth_token');
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(
          builder: (context)=> const LoginPage(),
        ),
      );
    }catch(e){
      _showMessage('Logout failed: $e');
    }
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Profile', style: bodyXLBold),
        automaticallyImplyLeading: false,
        centerTitle: true,
        backgroundColor: blue.shade300,
        actions: [
          IconButton(
            onPressed: (){}, 
            icon: const Icon(Icons.settings),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('User email: $userEmail', style: bodyLBold),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: BlueButton(
                    onPressed: logout, 
                    text: 'Log out'
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}