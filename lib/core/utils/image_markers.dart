import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';
import 'dart:io';

class CustomMarkerHelper {
  static Future<BitmapDescriptor> getCustomMarker(String imageUrl) async {
    final Uint8List markerIcon = await _getCircularBytesFromUrl(imageUrl);
    return BitmapDescriptor.fromBytes(markerIcon);
  }

  static Future<Uint8List> _getCircularBytesFromUrl(String imageUrl) async {
    final response = await http.get(Uri.parse(imageUrl));
    if (response.statusCode == 200) {
      final Uint8List imageData = response.bodyBytes;

      // Decode image
      final codec = await ui.instantiateImageCodec(imageData,
          targetWidth: 150, targetHeight: 150); // Increased size
      final frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      // Create a circular canvas
      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Paint paint = Paint()..isAntiAlias = true;

      final double size = 150.0;
      final Rect rect = Rect.fromLTWH(0, 0, size, size);

      // Clip to a circle
      canvas.clipPath(Path()..addOval(rect));
      canvas.drawImage(image, Offset.zero, paint);

      final ui.Image finalImage = await recorder
          .endRecording()
          .toImage(size.toInt(), size.toInt());

      final ByteData? byteData =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);
      return byteData!.buffer.asUint8List();
    } else {
      throw Exception("Failed to load image");
    }
  }
}
