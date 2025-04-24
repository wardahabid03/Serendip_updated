import 'package:flutter/material.dart';

class NavigationController {
  static void navigateToScreen(BuildContext context, int index) {
    String route;
    switch (index) {
      case 0:
        route = "/map"; // Home page
        break;
      case 1:
        route = "/find_friends";
        break;
      case 2:
        route = "/display_ad";
        break;
      case 3:
        route = "/view_profile";
        break;
      default:
        return;
    }

    // Prevent unnecessary navigation if already on the selected page
    if (ModalRoute.of(context)?.settings.name != route) {
      Navigator.pushReplacementNamed(context, route);
    }
  }
}
