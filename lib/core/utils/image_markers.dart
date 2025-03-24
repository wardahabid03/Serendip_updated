import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

class CustomMarkerHelper {
  /// Returns a circular custom marker from a given image URL.
  static Future<BitmapDescriptor> getCustomMarker(String imageUrl) async {
    print("➡ Fetching marker for: $imageUrl");
    
    final Uint8List markerIcon = await _getCircularBytesFromUrl(imageUrl);

    print("✅ Marker processing completed.");

    if (markerIcon.isEmpty) {
      print("⚠ Warning: Empty marker image, using default marker.");
      return BitmapDescriptor.defaultMarker; // Fallback if image fails
    }

    return BitmapDescriptor.fromBytes(markerIcon);
  }

  /// Downloads an image from URL, converts it into a circular marker, and returns Uint8List.
  static Future<Uint8List> _getCircularBytesFromUrl(String imageUrl) async {
    try {
      print("📡 Sending HTTP request to: $imageUrl");

      final response = await http.get(Uri.parse(imageUrl));
      print("📡 HTTP request completed with status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final Uint8List imageData = response.bodyBytes;
        print("📸 Image downloaded. Size: ${imageData.length} bytes");

        if (imageData.isEmpty) {
          throw Exception("❌ Downloaded image data is empty");
        }

        print("🖼 Decoding image...");
        final codec = await ui.instantiateImageCodec(
          imageData,
          targetWidth: 150, // Adjust marker size
          targetHeight: 150,
        );
        print("🖼 Image decoding completed.");

        final frame = await codec.getNextFrame();
        print("🖼 Extracted frame from codec.");

        final ui.Image image = frame.image;
        print("🖼 Image processed successfully.");

        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final Canvas canvas = Canvas(recorder);
        final Paint paint = Paint()..isAntiAlias = true;

        final double size = 150.0;
        final Rect rect = Rect.fromLTWH(0, 0, size, size);

        print("🎨 Preparing canvas for circular marker...");
        final Path path = Path()..addOval(rect);
        canvas.clipPath(path);
        canvas.drawImage(image, Offset.zero, paint);
        print("🎨 Image drawn on canvas.");

        final ui.Image finalImage =
            await recorder.endRecording().toImage(size.toInt(), size.toInt());

        print("🎨 Final image prepared.");

        final ByteData? byteData =
            await finalImage.toByteData(format: ui.ImageByteFormat.png);

        print("📦 ByteData conversion completed: ${byteData?.lengthInBytes} bytes");

        if (byteData == null) {
          throw Exception("❌ Failed to convert image to bytes");
        }

        print("✅ Successfully converted image to bytes.");
        return byteData.buffer.asUint8List();
      } else {
        throw HttpException("❌ Failed to load image: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Error loading image: $e");
      return Uint8List(0); // Return empty list to prevent crashes
    }
  }
}
