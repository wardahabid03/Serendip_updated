// ignore_for_file: prefer_const_constructors

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/chat/chat_provider.dart';
import 'package:serendip/features/location/location_provider.dart';
import 'package:serendip/features/profile.dart/provider/profile_provider.dart';
import 'package:serendip/firebase_options.dart';
import 'package:serendip/features/Auth/auth_provider.dart';
import 'package:serendip/core/routes.dart';
import 'core/theme/theme.dart';
import 'core/utils/navigator_key.dart';
import 'features/Map_view/Layers/trips_layer.dart';
import 'features/Map_view/controller/map_controller.dart';
import 'features/Social_Media/friend_request/friend_request_provider.dart';
import 'features/Trip_Tracking/provider/trip_provider.dart';
import 'package:flutter/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

   await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    print('Failed to initialize Firebase: $e');
  }

  final chatProvider = ChatProvider();
  chatProvider.listenForUnreadMessages();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core providers
        ChangeNotifierProvider<AuthProvider>(
          create: (_) => AuthProvider(),
        ),
        ChangeNotifierProvider<ProfileProvider>(
          create: (_) => ProfileProvider(),
        ),
        
        // Feature providers
        ChangeNotifierProvider<FriendRequestProvider>(
          create: (_) => FriendRequestProvider(),
        ),
        ChangeNotifierProvider<LocationProvider>(
          create: (_) => LocationProvider(),
        ),
        ChangeNotifierProvider<TripProvider>(
          create: (_) => TripProvider(),
        ),
        ChangeNotifierProvider<ChatProvider>(
          create: (_) => ChatProvider(),
        ),
        
        // Map-related providers
        ChangeNotifierProvider<TripsLayer>(
          create: (_) => TripsLayer(),
        ),
        ChangeNotifierProxyProvider<TripsLayer, MapController>(
          create: (context) => MapController(context.read<TripsLayer>()),
          update: (context, tripsLayer, previous) => 
              previous ?? MapController(tripsLayer),
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