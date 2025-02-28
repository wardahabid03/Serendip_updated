import 'package:flutter/material.dart';
import 'package:serendip/core/constant/colors.dart';


class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const PrimaryButton({
    Key? key,
    required this.text,
    required this.onPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0), // Small horizontal padding
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: tealColor, // Button color
          foregroundColor: Colors.white, // Text color
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // Rounded corners
          ),
          padding: const EdgeInsets.symmetric(vertical: 15), // Vertical padding
          minimumSize: Size(double.infinity, 50), // Make button full width with a minimum height
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16, // Font size
            fontWeight: FontWeight.w600, // Font weight
          ),
        ),
      ),
    );
  }
}
