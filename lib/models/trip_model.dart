import 'dart:convert'; // ✅ Required for JSON encoding/decoding
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:serendip/models/image_model.dart';

class TripModel {
  final String tripId;
  final String tripName;
  final String userId;
  final String description;
  final DateTime createdAt;
  final String privacy;
  final List<String> collaborators;
  List<ImageModel> images;
  List<LatLng> tripPath; // ✅ Now mutable (not final)
  bool isActive; // Field to track if the trip is active

  TripModel({
    required this.tripId,
    required this.tripName,
    required this.userId,
    required this.description,
    required this.createdAt,
    required this.privacy,
    required this.collaborators,
    required this.images,
    required this.tripPath,
    this.isActive = true, // Default to true when the trip starts
  });

  /// **✅ Converts Firestore document to a `TripModel`**
  factory TripModel.fromMap(Map<String, dynamic> data, String id) {
    List<LatLng> tripPath = [];

    if (data['trip_path'] is String) {
      try {
        final geoJson = jsonDecode(data['trip_path']); // ✅ Decode GeoJSON string
        if (geoJson['type'] == 'LineString' && geoJson['coordinates'] is List) {
          tripPath = (geoJson['coordinates'] as List).map((coord) {
            if (coord is List && coord.length == 2) {
              return LatLng(coord[1].toDouble(), coord[0].toDouble()); // ✅ GeoJSON format [lng, lat]
            }
            return null;
          }).where((point) => point != null).cast<LatLng>().toList();
        }
      } catch (e) {
        print('❌ Error decoding trip_path for trip $id: $e');
      }
    }

    return TripModel(
      tripId: id,
      tripName: data['trip_name'] ?? 'Unnamed Trip',
      userId: data['user_id'] ?? '',
      description: data['trip_description'] ?? '',
      createdAt: DateTime.tryParse(data['created_at']) ?? DateTime.now(),
      privacy: data['privacy'] ?? 'public',
      collaborators: List<String>.from(data['collaborators'] ?? []),
      images: (data['images'] as List?)?.map((e) => ImageModel.fromMap(e)).toList() ?? [],
      tripPath: tripPath,
      isActive: data['isActive'] ?? true,
    );
  }

  /// **✅ Converts `TripModel` to Firestore-compatible format**
  Map<String, dynamic> toMap() {
    return {
      'trip_name': tripName,
      'user_id': userId,
      'trip_description': description,
      'created_at': createdAt.toIso8601String(),
      'privacy': privacy,
      'collaborators': collaborators,
      'images': images.map((e) => e.toMap()).toList(),
      'trip_path': jsonEncode({
        "type": "LineString",
        "coordinates": tripPath.map((e) => [e.longitude, e.latitude]).toList(), // ✅ Store as GeoJSON string
      }),
      'isActive': isActive,
    };
  }
}
