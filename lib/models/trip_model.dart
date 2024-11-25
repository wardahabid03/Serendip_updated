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
  late final List<ImageModel> images;
  final List<LatLng> tripPath; // Coordinates representing the trip path
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
    required this.tripPath, // Initialize tripPath
    this.isActive = true, // Default to true when the trip starts
  });

  factory TripModel.fromMap(Map<String, dynamic> data, String id) {
    // Safely parse tripPath, ensuring latitude and longitude are valid
    List<LatLng> tripPath = [];
  if (data['trip_path'] is List) {
    print('Trip path data for trip $id: ${data['trip_path']}'); // Log raw trip_path data
    tripPath = (data['trip_path'] as List).map((e) {
      if (e['lat'] != null && e['lng'] != null) {
        return LatLng(e['lat'].toDouble(), e['lng'].toDouble());
      } else {
        print('Invalid coordinates found for trip: $id'); // Log invalid coordinates
        return null; // Return null if either latitude or longitude is missing
      }
    }).where((point) => point != null).cast<LatLng>().toList();
  } else {
    print('trip_path is not a list for trip: $id');
  }

    return TripModel(
      tripId: id,
      tripName: data['trip_name'] ?? 'Unnamed Trip', // Default name if missing
      userId: data['user_id'] ?? '', // Default to empty string if missing
      description: data['trip_description'] ?? '', // Default to empty if missing
      createdAt: DateTime.parse(data['created_at']), // Expect valid date format
      privacy: data['privacy'] ?? 'public', // Default privacy to 'public'
      collaborators: List<String>.from(data['collaborators'] ?? []),
      images: (data['images'] as List).map((e) => ImageModel.fromMap(e)).toList(),
      tripPath: tripPath, // Use the filtered tripPath
      isActive: data['isActive'] ?? true, // Default to true if the field is missing
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trip_name': tripName,
      'user_id': userId,
      'trip_description': description,
      'created_at': createdAt.toIso8601String(),
      'privacy': privacy,
      'collaborators': collaborators,
      'images': images.map((e) => e.toMap()).toList(),
      'trip_path': tripPath.map((e) => {'latitude': e.latitude, 'longitude': e.longitude}).toList(),
      'isActive': isActive, // Add isActive to the map
    };
  }
}
