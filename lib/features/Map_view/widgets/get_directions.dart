import 'dart:convert';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

class DirectionsService {
  static const String apiKey = "AIzaSyC4gULFHsrb14nNcNzQNwZa6tG0HNBIwmg";

  static Future<List<LatLng>> getDirections(
      LatLng origin, LatLng destination) async {
    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey";

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final String encodedPolyline =
          data['routes'][0]['overview_polyline']['points'];

      return _decodePolyline(encodedPolyline);
    } else {
      throw Exception("Failed to fetch directions: ${response.body}");
    }
  }

  static List<LatLng> _decodePolyline(String encodedPolyline) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(encodedPolyline);
    return decodedPoints
        .map((point) => LatLng(point.latitude.toDouble(), point.longitude.toDouble()))
        .toList();
  }
}
