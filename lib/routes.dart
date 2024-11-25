// lib/routes/app_routes.dart
import 'package:flutter/material.dart';
import 'package:serendip/screens/auth_screen.dart';
import 'package:serendip/screens/map_screen.dart';
// import 'package:your_app/screens/home/home_screen.dart';

// import 'package:your_app/screens/details/details_screen.dart';

class AppRoutes {
  static const String home = '/';
  static const String map = '/map';
    static const String auth = '/auth';
  static const String details = '/details';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      // case home:
      //   return MaterialPageRoute(builder: (_) => HomeScreen());
      case map:
        return MaterialPageRoute(builder: (_) => MapScreen());
        case auth:
        return MaterialPageRoute(builder: (_) => AuthScreen());
      // case details:
      //   return MaterialPageRoute(builder: (_) => DetailsScreen());
      default:
        return MaterialPageRoute(builder: (_) => MapScreen());
    }
  }
}
