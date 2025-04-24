// ignore_for_file: prefer_const_constructors

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';

import 'package:serendip/features/Ads/ads_provider.dart';
import 'package:serendip/features/Map_view/Layers/ad_layer.dart';
import 'package:serendip/features/Map_view/Layers/review_layer.dart';
import 'package:serendip/features/Map_view/Layers/trips_layer.dart';
import 'package:serendip/features/Map_view/controller/map_controller.dart';
import 'package:serendip/features/Reviews/review_provider.dart';
import 'package:serendip/features/chat/chat_provider.dart';
import 'package:serendip/features/location/location_provider.dart';
import 'package:serendip/features/profile.dart/provider/profile_provider.dart';
import 'package:serendip/features/Auth/auth_provider.dart';
import 'package:serendip/features/Social_Media/friend_request/friend_request_provider.dart';
import 'package:serendip/features/Trip_Tracking/provider/trip_provider.dart';
import 'package:serendip/firebase_options.dart';
import 'core/theme/theme.dart';
import 'core/utils/navigator_key.dart';
import 'core/routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  Stripe.publishableKey =
      'pk_test_51OKjZAHjNC2EIx6F7VG5nnoHEpT7gWgmHvWHvdN3T62A4rzy6DlLanRlWJfegBVNr3f6ke5LtUZXmC8EBeHTQc3400RmGeF6Bd';
  await Stripe.instance.applySettings();

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
        /// Core & Auth
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),

        /// Review feature
        ChangeNotifierProvider(create: (_) => ReviewProvider()),
        ChangeNotifierProvider(
          create: (context) => ReviewLayer(
            reviewProvider: context.read<ReviewProvider>(),
            context: context,
          ),
        ),

        /// Trip, Ads, Chat, Location, Friend Requests
        ChangeNotifierProvider(create: (_) => TripProvider()),
        ChangeNotifierProvider(create: (_) => BusinessAdsProvider()),
        ChangeNotifierProvider(create: (_) => ChatProvider()),
        ChangeNotifierProvider(create: (_) => LocationProvider()),
        ChangeNotifierProvider(create: (_) => FriendRequestProvider()),

        /// Map layers
        ChangeNotifierProvider(create: (_) => TripsLayer()),
        ChangeNotifierProvider(create: (_) => AdLayer()),

        /// MapController depends on TripsLayer, ReviewLayer, AdLayer
        ChangeNotifierProxyProvider3<TripsLayer, ReviewLayer, AdLayer,
            MapController>(
          create: (context) => MapController(
            context.read<TripsLayer>(),
            context.read<ReviewLayer>(),
            context.read<AdLayer>(),
          ),
          update: (context, tripsLayer, reviewLayer, adLayer, previous) =>
              previous ?? MapController(tripsLayer, reviewLayer, adLayer),
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
