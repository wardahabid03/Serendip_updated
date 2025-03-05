import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'dart:io';
import 'dart:async';
import 'package:image/image.dart' as img;

/// ✅ Converts a PNG image into a BitmapDescriptor with proper resizing
Future<BitmapDescriptor> getCustomIcon(String assetPath, {int width = 100}) async {
  final ByteData data = await rootBundle.load(assetPath);
  final Uint8List bytes = data.buffer.asUint8List();

  final img.Image? originalImage = img.decodeImage(bytes);
  if (originalImage == null) {
    throw Exception("Failed to decode PNG image");
  }

  final img.Image resizedImage = img.copyResize(originalImage, width: width);

  final Uint8List resizedBytes = Uint8List.fromList(img.encodePng(resizedImage));

  return BitmapDescriptor.fromBytes(resizedBytes);
}

/// ✅ Converts an SVG asset into a properly scaled BitmapDescriptor
Future<BitmapDescriptor> svgToBitmap(String assetPath, {int width = 100}) async {
  // Load the SVG as a picture
  final PictureInfo pictureInfo = await vg.loadPicture(SvgAssetLoader(assetPath), null);

  // Convert the picture into an image
  final ui.Image image = await pictureInfo.picture.toImage(width, width);

  // Convert the image to byte data in PNG format
  final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    throw Exception("Failed to convert SVG to BitmapDescriptor");
  }

  // Convert the byte data into a Uint8List
  final Uint8List uint8List = byteData.buffer.asUint8List();

  // Return the bitmap descriptor
  return BitmapDescriptor.fromBytes(uint8List);
}
