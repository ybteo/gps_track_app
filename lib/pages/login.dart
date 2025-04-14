import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:gpsapp/constant/const.dart';
import 'package:gpsapp/constant/textstyle.dart';
import 'package:gpsapp/widgets/bottomNaviBar.dart';
import 'package:gpsapp/widgets/buttonStyle.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  TextEditingController emailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool _isVisible = false;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  

  Future<void> signIn() async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: emailController.text.trim(), 
        password: passwordController.text.trim(),
      );

      String? token = await userCredential.user?.getIdToken();
      if(token != null){
      final FlutterSecureStorage secureStorage = FlutterSecureStorage();
      await secureStorage.write(key: 'auth_token', value: token);
      }

      // Navigate to the BottomNaviBar on success
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => const BottomNaviBar()
        ),
      );

    } on FirebaseAuthException catch (e) {
      // Show error messages based on error codes
      String message;
      if (e.code == 'user-not-found') {
        message = 'No user found for this email.'; // not working
      } else if (e.code == 'wrong-password') {
        message = 'Incorrect password. Please try again.'; //not-working
      } else {
        message = 'Something went wrong. Please try again later.';
      }
      showErrorDialog(message);
    } catch (e) {
      showErrorDialog('An unexpected error occurred.');
    }
  }


  void showErrorDialog(String message) {
    // if(!mounted){
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: blue.shade100,
            title: Text('Login Error', style: heading4Bold),
            content: Text(message, style: bodyLMedium),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK', style: bodyXLBold.copyWith(color: blue.shade900)),
              ),
            ],
          );
        },
      );
    // }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      resizeToAvoidBottomInset: false,

      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
          
                Image.asset('assets/images/gps_logo.png', height: 150, width: 450),
          
              
                const SizedBox(height: 30),
                Text(('Email'), style: heading6Bold),
                  const SizedBox(height: 5),
                  TextField(
                    onChanged: (value){
                      setState(() {
                        //_isEmailValid = _isEmailValidFunction(value);
                      });
                    },
                    controller: emailController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: blue.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,                
                      ),
                      isDense: true,
                      hintText: 'Email',
                      hintStyle: bodyLRegular,
                      prefixIcon: const Icon(Icons.message),
                     
                    ),
                  ),
          
                  const SizedBox(height: 25),
          
                  Text('Password', style: heading6Bold),
                  const SizedBox(height: 5),
                  TextField(
                    onChanged:(value){
                      setState(() {
                        //_isPasswordValid = _isPasswordValidFunction(value);
                      });
                    },
                    controller: passwordController,
                    obscureText: !_isVisible,
                    decoration: InputDecoration(
                      suffixIcon: IconButton(
                        onPressed: (){
                          setState(() {
                            _isVisible = !_isVisible;
                          });
                        },
                        icon: _isVisible? const Icon(Icons.visibility):const Icon(Icons.visibility_off),
                      ),
                      filled: true,
                      fillColor: blue.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,                
                      ),
                      isDense: true,
                      hintText: 'Password',
                      hintStyle: bodyLRegular,
                      prefixIcon: const Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 85.0),
          
                  Row(
                    children: [
                      Expanded(
                        child: BlueButton(
                          onPressed: () async {
                            await signIn();
                          }, 
                          text: 'Log In'
                        ),
                      ),
                    ],
                  ),
                  
              ],
            ),
          ),
        ),
      ),
    );
  }
}