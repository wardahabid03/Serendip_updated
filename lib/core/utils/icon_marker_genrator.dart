import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui; // Ensure this import is included

class MarkerIconGenerator {
  static Future<BitmapDescriptor> createUniversalMarker({
    Color backgroundColor = Colors.yellow,
    double size = 150,
  }) async {
    final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(pictureRecorder);
    final Paint paint = Paint()..color = backgroundColor;

    final double radius = size / 2;

    // Draw the background circle
    canvas.drawCircle(Offset(radius, radius), radius, paint);

    // Draw the location pin inside the circle (📍 emoji)
    final TextPainter textPainter = TextPainter(
      text: TextSpan(
        text: '📍', // Universal pin emoji
        style: TextStyle(fontSize: size * 0.6, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(radius - textPainter.width / 2, radius - textPainter.height / 2),
    );

    // Convert the drawing to an image
    final img = await pictureRecorder.endRecording().toImage(size.toInt(), size.toInt());
    final data = await img.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(data!.buffer.asUint8List());
  }
}
