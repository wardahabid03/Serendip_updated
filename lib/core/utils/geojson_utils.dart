import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'dart:convert';

class GeoJSONUtils {
  /// Convert a list of LatLng points to a GeoJSON LineString format
  static Map<String, dynamic> latLngListToGeoJSON(List<LatLng> points) {
    return {
      "type": "LineString",
      "coordinates": points.map((point) => [point.longitude, point.latitude]).toList(),
    };
  }

  /// Convert a GeoJSON LineString to a list of LatLng points
  static List<LatLng> geoJSONToLatLngList(Map<String, dynamic> geoJSON) {
    if (geoJSON["type"] != "LineString" || geoJSON["coordinates"] == null) {
      throw Exception("Invalid GeoJSON format");
    }
    return (geoJSON["coordinates"] as List)
        .map((coord) => LatLng(coord[1], coord[0]))
        .toList();
  }

  /// Convert a list of LatLng to a GeoJSON string
  static String latLngListToGeoJSONString(List<LatLng> points) {
    return jsonEncode(latLngListToGeoJSON(points));
  }

  /// Convert a GeoJSON string to a list of LatLng
  static List<LatLng> geoJSONStringToLatLngList(String geoJSONString) {
    return geoJSONToLatLngList(jsonDecode(geoJSONString));
  }
}
