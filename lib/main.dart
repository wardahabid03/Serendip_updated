// ignore_for_file: prefer_const_constructors

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/firebase_options.dart';
import 'package:serendip/providers/auth_provider.dart';
// import 'package:serendip/providers/privacy_provider.dart';
// import 'package:serendip/providers/trip_provider.dart';
import 'package:serendip/routes.dart'; // Import the routes file
// import 'providers/auth_provider.dart';
// import 'providers/location_provider.dart';
// import 'components/marker_widget.dart';
import 'colors.dart';
// import 'package:serendip/providers/image_provider.dart' as custom_image_provider; // Use alias


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(  options: DefaultFirebaseOptions.currentPlatform,);
  } catch (e) {
    print('Failed to initialize Firebase: $e');
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        //  ChangeNotifierProvider(create: (_) => custom_image_provider.ImageProvider(MarkerProvider())),
        //  ChangeNotifierProvider(create: (_) => PrivacyProvider()),
        // ChangeNotifierProvider(create: (_) => LocationProvider()),
        // ChangeNotifierProvider(create: (_) => MarkerProvider()), // Ensure MarkerProvider is correct
        //   ChangeNotifierProvider(create: (_) => TripProvider()),
      ],
      child: MaterialApp(
         debugShowCheckedModeBanner: false,
        title: 'Serendip',
        theme: ThemeData(
          primaryColor: tealColor,
          hintColor: eggShellColor,
          scaffoldBackgroundColor: eggShellColor,
          appBarTheme: AppBarTheme(
            backgroundColor: tealColor,
            foregroundColor: eggShellColor,
          ),
          buttonTheme: ButtonThemeData(
            buttonColor: tealColor,
            textTheme: ButtonTextTheme.accent,
          ),
        ),
        initialRoute: AppRoutes.auth, // Define initial route
        onGenerateRoute: AppRoutes.generateRoute, // Use the route generator
      ),
    );
  }
}
