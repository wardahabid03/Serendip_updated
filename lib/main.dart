// ignore_for_file: prefer_const_constructors

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/chat/chat_provider.dart';
import 'package:serendip/features/location/location_provider.dart';
import 'package:serendip/features/profile.dart/provider/profile_provider.dart';
import 'package:serendip/firebase_options.dart';
import 'package:serendip/features/Auth/auth_provider.dart';
import 'package:serendip/core/routes.dart'; // Import the routes file
import 'core/theme/theme.dart';
import 'core/utils/navigator_key.dart';
import 'features/Map_view/Layers/trips_layer.dart';
import 'features/Map_view/controller/map_controller.dart';
import 'features/Social_Media/friend_request/friend_request_provider.dart';
import 'features/Trip_Tracking/provider/trip_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Failed to initialize Firebase: $e');
  }

  final chatProvider = ChatProvider();
  chatProvider.listenForUnreadMessages(); // Start listening early

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => FriendRequestProvider()),
        ChangeNotifierProvider(create: (context) => LocationProvider()),
        ChangeNotifierProvider(create: (context) => TripProvider()),
        ChangeNotifierProvider(create: (context) => ChatProvider()),

        // ✅ Provide TripsLayer first
        ChangeNotifierProvider(create: (context) => TripsLayer()), 

        // ✅ Corrected ChangeNotifierProxyProvider setup
        ChangeNotifierProxyProvider<TripsLayer, MapController>(
          create: (context) => MapController(context.read<TripsLayer>()), // Initialize properly
          update: (context, tripsLayer, previous) =>
              previous ?? MapController(tripsLayer), // Ensure updates
        ),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Serendip',
        theme: AppTheme.lightTheme,
        initialRoute: AppRoutes.splash,
        onGenerateRoute: AppRoutes.generateRoute,
        navigatorKey: navigatorKey,
      ),
    );
  }
}
