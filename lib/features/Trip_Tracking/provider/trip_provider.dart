import 'dart:io';
import 'package:cloudinary/cloudinary.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:serendip/models/trip_model.dart';
import 'package:serendip/core/utils/geojson_utils.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/navigator_key.dart';
import '../../Map_view/Layers/trips_layer.dart';
import '../../Map_view/controller/map_controller.dart';

class TripProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  TripModel? _currentTrip;
  bool _isRecording = false;
  List<LatLng> _tripPath = [];
  List<TripModel> _trips = [];

  Set<Polyline> _polylines = {}; // Store polylines for active trips
  Set<Marker> _markers = {}; // Store markers (e.g., red circle for active trip)

  TripModel? get currentTrip => _currentTrip;
  bool get isRecording => _isRecording;
  List<TripModel> get trips => _trips;
  Set<Polyline> get polylines => _polylines;
  Set<Marker> get markers => _markers;

String? getCurrentUserId() {
  User? user = FirebaseAuth.instance.currentUser;
  return user?.uid;
}
  
  final cloudinary = Cloudinary.signedConfig(
    apiKey: '935742635189255',
    apiSecret: 'u_1cFQsYmXSrXoDL_6gJbQWvQcA',
    cloudName: 'dup7xznsc',
  );

  /// **Start a new trip**
  void startTrip(String tripName, String userId, String description, String privacy, List<String> collaborators, LatLng startLocation) {
    print("🚀 startTrip() called in TripProvider!");

    _tripPath.clear();
    _isRecording = true;

    if (!collaborators.contains(userId)) {
      collaborators.add(userId);
    }

    _currentTrip = TripModel(
      tripId: const Uuid().v4(),
      tripName: tripName,
      userId: userId,
      description: description,
      createdAt: DateTime.now(),
      privacy: privacy,
      collaborators: collaborators,
      images: [],
      tripPath: [],
      isActive: true,
    );

    print("📍 Adding first location: $startLocation");
    _tripPath.add(startLocation);
    _currentTrip!.tripPath.add(startLocation);

    // 🔹 Update the map immediately after starting
    final mapController = Provider.of<MapController>(
      navigatorKey.currentState!.overlay!.context,
      listen: false,
    );
    
    mapController.addTripPolyline(_tripPath, "active_trip"); // ✅ Ensure polyline is added
    mapController.addActiveTripCircle(startLocation); // ✅ Ensure red circle is added

    notifyListeners();
    print("🔄 notifyListeners() called after starting trip!");
  }

  /// **Add location during trip recording**
  void addLocation(LatLng location) {
    if (_isRecording) {
      print("📍 New location added: $location");
      _tripPath.add(location);
      _currentTrip?.tripPath.add(location);

      final mapController = Provider.of<MapController>(
        navigatorKey.currentState!.overlay!.context,
        listen: false,
      );
      
      mapController.addTripPolyline(_tripPath, "active_trip"); // ✅ Update polyline
      mapController.addActiveTripCircle(location); // ✅ Update red circle

      notifyListeners();
      print("🔄 notifyListeners() called after adding location!");
    } else {
      print("⚠️ Tried to add location, but recording is off!");
    }
  }

Future<void> captureImage(File imageFile, LatLng location, BuildContext context) async {
  if (_currentTrip == null) {
    print("⚠️ No active trip to save the image.");
    return;
  }

  try {
    String imageId = const Uuid().v4();

    // Upload image to Cloudinary
    final response = await cloudinary.upload(
      file: imageFile.path,
      fileBytes: await imageFile.readAsBytes(),
      resourceType: CloudinaryResourceType.image,
      folder: 'trip_images/${_currentTrip!.tripId}',
    );

    if (response.isSuccessful) {
      String imageUrl = response.secureUrl!;

      // Save image details to Firestore
      await _firestore
          .collection('trips')
          .doc(_currentTrip!.tripId)
          .collection('images')
          .doc(imageId)
          .set({
        'image_id': imageId, // 🔹 Store ID for consistency
        'image_url': imageUrl,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'timestamp': DateTime.now(),
      });

      print("✅ Image uploaded & stored successfully!");

      // ✅ Access `TripsLayer` and add the image marker
      final tripsLayer = Provider.of<TripsLayer>(context, listen: false);

      print('abc');
      tripsLayer.addImageMarkerFromTripProvider(imageId, location, imageUrl, context);
print('abcd');
      notifyListeners();
    }
  } catch (e) {
    print("❌ Error uploading image: $e");
  }
}



   /// **Add trip ID to a user's document in Firestore**
Future<void> addTripToUser(String userId, String tripId) async {
  final userRef = _firestore.collection('users').doc(userId);
  print('trip 1');

  await _firestore.runTransaction((transaction) async {
    final userSnapshot = await transaction.get(userRef);
    if (!userSnapshot.exists) return;
 print('trip 2');
    final currentCount = userSnapshot.data()?['tripCount'] ?? 0;
     print('trip 3');
    transaction.update(userRef, {
      'trips': FieldValue.arrayUnion([tripId]),
      'tripCount': currentCount + 1,
      
    });
     print('trip 4');
  });
}


// **Save the trip to Firestore**
  Future<String> _saveTripToFirestore() async {
    if (_currentTrip == null) return '';

    final tripMap = _currentTrip!.toMap();
    tripMap['trip_path'] = GeoJSONUtils.latLngListToGeoJSONString(_currentTrip!.tripPath);

    await _firestore.collection('trips').doc(_currentTrip!.tripId).set(tripMap);
    return _currentTrip!.tripId;
  }



  Future<void> stopTrip(LatLng endLocation) async {
    if (_currentTrip == null) return;

    _isRecording = false;
    _tripPath.add(endLocation);
    _currentTrip!.tripPath = _tripPath;
    _currentTrip!.isActive = false;

    String tripId = await _saveTripToFirestore();

    await addTripToUser(_currentTrip!.userId, tripId);

    for (String collaboratorId in _currentTrip!.collaborators) {
      if (collaboratorId != _currentTrip!.userId) {
        await addTripToUser(collaboratorId, tripId);
      }
    }

    // 🔹 Clear the active trip polyline
    final mapController = Provider.of<MapController>(
      navigatorKey.currentState!.overlay!.context,
      listen: false,
    );
    mapController.clearLayer("trips_layer");

    _currentTrip = null;
    notifyListeners();
  }

  Future<void> fetchTrips({required String userId, required String filter}) async {
    QuerySnapshot tripSnapshot;

    if (filter == 'My Trips') {
      tripSnapshot = await _firestore
          .collection('trips')
          .where('user_id', isEqualTo: userId)
          .get();
    } else if (filter == 'Friends\' Trips') {
      List<String> friends = [];
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .get();
      friends = friendsSnapshot.docs.map((doc) => doc.id).toList();
      if (friends.isNotEmpty) {
        tripSnapshot = await _firestore
            .collection('trips')
            .where('user_id', whereIn: friends)
            .where('privacy', whereIn: ['friends', 'public']) 
            .get();
      } else {
        return;
      }
    } else {
      tripSnapshot = await _firestore
          .collection('trips')
          .where('collaborators', arrayContains: userId)
          .get();
    }

    _trips = tripSnapshot.docs
        .map((doc) => TripModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
        .toList();

    notifyListeners();
  }

  Future<TripModel?> fetchTripById(String tripId) async {
    try {
      final tripDoc = await _firestore.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) return null;

      final data = tripDoc.data();
      if (data == null) return null;

      return TripModel.fromMap(data, tripDoc.id);
    } catch (e) {
      return null;
    }
  }




Future<List<Map<String, dynamic>>> fetchTripImages(String tripId) async {
  try {
    final snapshot = await _firestore
        .collection('trips')
        .doc(tripId)
        .collection('images')
        .get();

    return snapshot.docs.map((doc) {
      return {
        'image_url': doc['image_url'],
        'latitude': doc['latitude'],
        'longitude': doc['longitude'],
        'timestamp': doc['timestamp'],
      };
    }).toList();
  } catch (e) {
    print("Error fetching images for trip $tripId: $e");
    return [];
  }
}


Future<void> deleteTrip(String tripId) async {
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
    String? currentUserId = getCurrentUserId();
  WriteBatch batch = firestore.batch();

  try {
    // Reference to the trip document
    DocumentReference tripRef = firestore.collection('trips').doc(tripId);

    // Reference to user document
    DocumentReference userRef = firestore.collection('users').doc(currentUserId);

    // Get the user document snapshot
    DocumentSnapshot userSnapshot = await userRef.get();

    if (!userSnapshot.exists) {
      throw Exception("User document does not exist");
    }

    // Extract user's tripCount (default to 0 if not present)
    int tripCount = (userSnapshot['tripCount'] ?? 0) - 1;
    if (tripCount < 0) tripCount = 0; // Ensure tripCount is not negative

    // Delete the trip document
    batch.delete(tripRef);

    // Remove the trip ID from the user's trips list and update tripCount
    batch.update(userRef, {
      'trips': FieldValue.arrayRemove([tripId]),
      'tripCount': tripCount, // Update the trip count
    });

    // Commit batch
    await batch.commit();
    print("✅ Trip deleted successfully.");
  } catch (e) {
    print("❌ Error deleting trip: $e");
  }
}

Future<void> deleteTripImage(String tripId, String imageId) async {
  print("------------");
  print(tripId);
    print(imageId);

  try {
    // Reference to Firestore image document
    DocumentReference imageRef = _firestore.collection('trips').doc(tripId).collection('images').doc(imageId);

    // Get image data before deleting
    DocumentSnapshot imageSnapshot = await imageRef.get();
    if (!imageSnapshot.exists) return;

    Map<String, dynamic>? imageData = imageSnapshot.data() as Map<String, dynamic>?;
    String imageUrl = imageData?['image_url'] ?? '';

    // Delete image from Firebase Storage
    // if (imageUrl.isNotEmpty) {
    //   await _storage.refFromURL(imageUrl).delete();
    // }

    // Remove image from Firestore
    await imageRef.delete();

    print("✅ Image deleted successfully.");

    // Remove marker from the map
    _markers.removeWhere((marker) => marker.markerId.value == imageId);
    notifyListeners();
  } catch (e) {
    print("❌ Error deleting image: $e");
  }
}




   void updateActiveTripOnMap() {
    if (_currentTrip != null && _isRecording) {
      notifyListeners();
    }
  }


  Stream<List<Map<String, dynamic>>> getTripImagesStream(String tripId) {
  return FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('images')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
}

}
