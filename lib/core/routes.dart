// lib/routes/app_routes.dart
import 'package:flutter/material.dart';
import 'package:serendip/features/Auth/auth_screen.dart';
import 'package:serendip/features/Social_Media/find_friends/search_friends_page.dart';
import 'package:serendip/features/Social_Media/friend_request/friend_request_screen.dart';
import 'package:serendip/features/Splash_Screen/splash_screen.dart';
import 'package:serendip/features/Walkthrough/walkthrough_screen.dart';
import 'package:serendip/features/profile.dart/presentation/profile_screen.dart';
import 'package:serendip/features/profile.dart/setting_screen.dart';
import 'package:serendip/models/trip_model.dart';

import '../features/Map_view/map_screen.dart';
import '../features/profile.dart/presentation/view_profile.dart';
// import 'package:serendip/screens/map_screen.dart';
// import 'package:your_app/screens/home/home_screen.dart';

// import 'package:your_app/screens/details/details_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String map = '/map';
  static const String auth = '/auth';
  static const String details = '/details';
  static const String find_friends = '/find_friends';
  static const String create_profile = '/create_profile';
  static const String splash = '/splash';
  static const String walkthrough = '/walkthrough';
  static const String view_profile = '/view_profile';
  static const String settingsscreen = '/settingsscreen';
  static const String view_requests = '/view_requests';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // case home:
      //   return MaterialPageRoute(builder: (_) => HomeScreen());
case map:
  final args = settings.arguments as Map<String, dynamic>?;

  final TripModel? trip = args?['trip'] != null
      ? TripModel.fromMap(args!['trip'], args['trip']['tripId']) // ✅ Extract tripId properly
      : null;

  return MaterialPageRoute(
    builder: (_) => MapScreen(trip: trip),
  );




      case auth:
        return MaterialPageRoute(builder: (_) => AuthScreen());
      case find_friends:
        return MaterialPageRoute(builder: (_) => FindFriendsPage());
      case create_profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      case settingsscreen:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      case splash:
        return MaterialPageRoute(builder: (_) => SplashScreen());
      case walkthrough:
        return MaterialPageRoute(builder: (_) => WalkthroughScreen());
         case view_requests:
        return MaterialPageRoute(builder: (_) => FriendRequestPage());
        
      case view_profile:
        return MaterialPageRoute(
          builder: (_) =>
              ViewProfileScreen(userId: settings.arguments as String?),
        );

      // case details:
      //   return MaterialPageRoute(builder: (_) => DetailsScreen());
      default:
        return MaterialPageRoute(builder: (_) => MapScreen());
    }
  }
}
