import 'dart:math';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class PolylineSimplification {
  /// Simplifies a polyline using the Ramer-Douglas-Peucker algorithm.
  /// [tolerance] controls the degree of simplification (higher = more aggressive).
  static List<LatLng> simplifyPath(List<LatLng> path, double tolerance) {
    if (path.length < 3) return path; // No need to simplify

    return _rdp(path, tolerance);
  }

  /// Recursive Ramer-Douglas-Peucker (RDP) implementation
  static List<LatLng> _rdp(List<LatLng> points, double epsilon) {
    double maxDistance = 0.0;
    int index = 0;

    // Find the point farthest from the line between first and last
    for (int i = 1; i < points.length - 1; i++) {
      double distance = _perpendicularDistance(points[i], points.first, points.last);
      if (distance > maxDistance) {
        maxDistance = distance;
        index = i;
      }
    }

    // If maxDistance is greater than epsilon, recursively simplify
    if (maxDistance > epsilon) {
      List<LatLng> left = _rdp(points.sublist(0, index + 1), epsilon);
      List<LatLng> right = _rdp(points.sublist(index), epsilon);

      return [...left, ...right.sublist(1)];
    } else {
      return [points.first, points.last]; // Only keep endpoints
    }
  }

  /// Calculates perpendicular distance of a point from a line
  static double _perpendicularDistance(LatLng point, LatLng start, LatLng end) {
    double dx = end.longitude - start.longitude;
    double dy = end.latitude - start.latitude;

    if (dx == 0 && dy == 0) {
      return _haversineDistance(point, start);
    }

    double t = ((point.longitude - start.longitude) * dx + (point.latitude - start.latitude) * dy) /
        (dx * dx + dy * dy);
    
    t = t.clamp(0, 1);

    LatLng projection = LatLng(start.latitude + t * dy, start.longitude + t * dx);
    return _haversineDistance(point, projection);
  }

  /// Computes Haversine distance (great-circle distance)
  static double _haversineDistance(LatLng point1, LatLng point2) {
    const double radius = 6371; // Earth's radius in km
    double lat1 = _toRadians(point1.latitude);
    double lat2 = _toRadians(point2.latitude);
    double dLat = _toRadians(point2.latitude - point1.latitude);
    double dLon = _toRadians(point2.longitude - point1.longitude);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return radius * c; // Distance in km
  }

  /// Converts degrees to radians
  static double _toRadians(double degree) => degree * (pi / 180);
}
