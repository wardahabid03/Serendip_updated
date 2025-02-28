import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:serendip/core/constant/colors.dart';

void showDialogBox(
  BuildContext context, {
  required String animationPath,
  required String title,
  required String content,
  VoidCallback? onConfirm,
}) {
  showDialog(
    context: context,
    barrierDismissible: false, // Prevent accidental dismiss
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Rounded corners
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(animationPath, height: 120, width: 120), // Lottie animation
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold,color: tealColor)),
          const SizedBox(height: 8),
          Text(content, textAlign: TextAlign.center),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop(); // Close dialog
            onConfirm?.call(); // Execute additional action if provided
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );
}