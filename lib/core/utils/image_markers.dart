import 'dart:io';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class CustomMarkerHelper {
  /// Returns a circular custom marker from a given image URL.
  static Future<BitmapDescriptor> getCustomMarker(String imageUrl) async {
    try {
      final Uint8List markerIcon = await _getCircularBytesFromUrl(imageUrl);

      if (markerIcon.isEmpty) {
        debugPrint("⚠ Warning: Empty marker image, using default marker.");
        return BitmapDescriptor.defaultMarker;
      }

      return BitmapDescriptor.fromBytes(markerIcon);
    } catch (e) {
      debugPrint("❌ Error in getCustomMarker: $e");
      return BitmapDescriptor.defaultMarker;
    }
  }

  /// Downloads an image from URL and converts it into a circular marker.
  static Future<Uint8List> _getCircularBytesFromUrl(String imageUrl) async {
    try {
      final response = await http.get(Uri.parse(imageUrl));

      if (response.statusCode == 200) {
        return await _convertToCircularMarker(response.bodyBytes);
      } else {
        throw HttpException("❌ Failed to load image: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error loading image: $e");
      return Uint8List(0);
    }
  }

  /// Converts an image into a circular marker with increased size.
  static Future<Uint8List> _convertToCircularMarker(Uint8List imageData) async {
    try {
      const double markerSize = 150.0; // Increased size (adjust as needed)
      final codec =
          await ui.instantiateImageCodec(imageData, targetWidth: markerSize.toInt());
      final frame = await codec.getNextFrame();
      final ui.Image image = frame.image;

      final ui.PictureRecorder recorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(recorder);
      final Paint paint = Paint()..isAntiAlias = true;

      final Rect rect = Rect.fromLTWH(0, 0, markerSize, markerSize);
      final Path path = Path()..addOval(rect);

      canvas.clipPath(path);
      canvas.drawImage(image, Offset.zero, paint);

      final ui.Image finalImage =
          await recorder.endRecording().toImage(markerSize.toInt(), markerSize.toInt());

      final ByteData? byteData =
          await finalImage.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception("❌ Failed to convert image to bytes");
      }

      return byteData.buffer.asUint8List();
    } catch (e) {
      debugPrint("❌ Error in _convertToCircularMarker: $e");
      return Uint8List(0);
    }
  }
}
