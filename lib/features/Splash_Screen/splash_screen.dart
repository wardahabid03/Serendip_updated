import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:serendip/core/constant/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/routes.dart';

class SplashScreen extends StatefulWidget {
  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkFirstInstall();
  }

  Future<void> _checkFirstInstall() async {
    final prefs = await SharedPreferences.getInstance();
    bool isFirstInstall = prefs.getBool('isFirstInstall') ?? true; // Default: true
    bool isLoggedIn = prefs.getBool('isLoggedIn') ?? false;

    await Future.delayed(const Duration(seconds: 3)); // Splash duration

    if (isFirstInstall) {
      prefs.setBool('isFirstInstall', false); // Mark first install as false
      Navigator.pushReplacementNamed(context, AppRoutes.walkthrough);
    } else if (isLoggedIn) {
      Navigator.pushReplacementNamed(context, AppRoutes.map);
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.auth);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eggShellColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              "assets/location.json", // Ensure the file exists in assets
              width: 100,
              fit: BoxFit.cover,
            ),
            const SizedBox(height: 20),
            const Text(
              "Serendip", // App Name
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: tealColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
