import 'package:flutter/material.dart';

// Main Colors
const Color tealColor = Color(0xFF008080);       // Main teal color
const Color grayColor = Color(0xFF706D6D);       // Gray color
const Color eggShellColor = Color(0xFFFFFFFF);   // Eggshell color

// Teal Color Swatch
const int _tealPrimaryValue = 0xFF008080; 

const MaterialColor tealSwatch = MaterialColor(
  _tealPrimaryValue,
  <int, Color>{
    50: Color(0xFFE0F2F2),
    100: Color(0xFFB3DFDF),
    200: Color(0xFF80CACA),
    300: Color(0xFF4DB4B4),
    400: Color(0xFF26A3A3),
    500: Color(_tealPrimaryValue), // Primary color
    600: Color(0xFF007878),
    700: Color(0xFF006B6B),
    800: Color(0xFF005E5E),
    900: Color(0xFF004545),
  },
);
