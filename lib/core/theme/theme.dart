import 'package:flutter/material.dart';
import 'package:serendip/core/constant/colors.dart'; // Import your colors

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      fontFamily: "Poppins", // Set global font
      primarySwatch: tealSwatch, // Ensure it's being used globally
      scaffoldBackgroundColor: eggShellColor,
      hintColor: grayColor,
      colorScheme: ColorScheme.fromSwatch(
        primarySwatch: tealSwatch,
      ).copyWith(
        secondary: grayColor, // Use grayColor as the secondary color
        background: eggShellColor,
        surface: eggShellColor,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: tealColor,
        foregroundColor: eggShellColor,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tealColor, // Use the swatch color
          foregroundColor: eggShellColor,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black),
        bodyMedium: TextStyle(color: Colors.black87),
      ),
    );
  }
}
