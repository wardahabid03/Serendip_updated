import 'package:flutter/material.dart';
import 'package:serendip/core/constant/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/routes.dart';

class WalkthroughScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eggShellColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              "assets/splash_image.png", // Replace with your walkthrough image
              width: double.infinity,
            ),
            const SizedBox(height: 30),
            const Text(
              "Travel Far,\nShare Closer",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: tealColor,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              "Let’s Travel, Tag & Inspire",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: tealColor,
              ),
            ),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                prefs.setBool('isFirstInstall', false); // Mark walkthrough as seen
                Navigator.pushReplacementNamed(context, AppRoutes.auth);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: tealColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
              ),
              child: const Text(
                "Get Started",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
