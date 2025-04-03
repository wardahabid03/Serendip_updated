import 'dart:io';
import 'dart:async';
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
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

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
  bool _isUploading = false;

  Set<Polyline> _polylines = {};
  Set<Marker> _markers = {};

  TripModel? get currentTrip => _currentTrip;
  bool get isRecording => _isRecording;
  List<TripModel> get trips => _trips;
  Set<Polyline> get polylines => _polylines;
  Set<Marker> get markers => _markers;
  bool get isUploading => _isUploading;

  // Queue for pending uploads
  final List<Map<String, dynamic>> _pendingImageUploads = [];
  Timer? _uploadRetryTimer;
  Timer? _saveTripTimer;

  String? getCurrentUserId() {
    User? user = FirebaseAuth.instance.currentUser;
    return user?.uid;
  }
  
  final cloudinary = Cloudinary.signedConfig(
    apiKey: '935742635189255',
    apiSecret: 'u_1cFQsYmXSrXoDL_6gJbQWvQcA',
    cloudName: 'dup7xznsc',
  );

  TripProvider() {
    _initializeFromStorage();
    _startUploadRetryTimer();
    _checkConnectivity();
  }

  Future<void> _initializeFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final tripJson = prefs.getString('current_trip');
    
    if (tripJson != null) {
      final tripData = json.decode(tripJson);
      _currentTrip = TripModel.fromMap(tripData, tripData['tripId']);
      _isRecording = true;
      _tripPath = _currentTrip!.tripPath;
      notifyListeners();
    }

    // Load pending image uploads
    final pendingUploads = prefs.getStringList('pending_uploads') ?? [];
    _pendingImageUploads.addAll(
      pendingUploads.map((upload) => json.decode(upload) as Map<String, dynamic>)
    );
  }

  void _startUploadRetryTimer() {
    _uploadRetryTimer?.cancel();
    _uploadRetryTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _processPendingUploads();
    });
  }

  Future<void> _checkConnectivity() async {
    final connectivity = Connectivity();
    connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _processPendingUploads();
      }
    });
  }

  Future<void> _saveTripToStorage() async {
    if (_currentTrip == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('current_trip', json.encode(_currentTrip!.toMap()));
  }

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

    _saveTripToStorage();

    // Start periodic saving of trip data
    _saveTripTimer?.cancel();
    _saveTripTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _saveTripToStorage();
    });

    final mapController = Provider.of<MapController>(
      navigatorKey.currentState!.overlay!.context,
      listen: false,
    );
    
    mapController.addTripPolyline(_tripPath, "active_trip");
    mapController.addActiveTripCircle(startLocation);

    notifyListeners();
    print("🔄 notifyListeners() called after starting trip!");
  }

  void addLocation(LatLng location) {
    if (_isRecording) {
      print("📍 New location added: $location");
      _tripPath.add(location);
      _currentTrip?.tripPath.add(location);

      _saveTripToStorage();

      final mapController = Provider.of<MapController>(
        navigatorKey.currentState!.overlay!.context,
        listen: false,
      );
      
      mapController.addTripPolyline(_tripPath, "active_trip");
      mapController.addActiveTripCircle(location);

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

    if (_isUploading) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please wait for the previous upload to complete'))
      );
      return;
    }

    try {
      _isUploading = true;
      notifyListeners();

      String imageId = const Uuid().v4();
      final directory = await getApplicationDocumentsDirectory();
      final savedImagePath = '${directory.path}/$imageId.jpg';
      await imageFile.copy(savedImagePath);

      final uploadData = {
        'imageId': imageId,
        'imagePath': savedImagePath,
        'tripId': _currentTrip!.tripId,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'timestamp': DateTime.now().toIso8601String(),
      };

      // Check connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        // Store for later upload
        _pendingImageUploads.add(uploadData);
        final prefs = await SharedPreferences.getInstance();
        final pendingUploads = _pendingImageUploads.map((upload) => json.encode(upload)).toList();
        await prefs.setStringList('pending_uploads', pendingUploads);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image saved and will be uploaded when online'))
        );
      } else {
        await _uploadImage(uploadData, context);
      }
    } catch (e) {
      print("❌ Error handling image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving image: ${e.toString()}'))
      );
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

Future<void> _uploadImage(Map<String, dynamic> uploadData, BuildContext context) async {
  if (_isUploading) return; // Prevent multiple simultaneous uploads
  _isUploading = true;

  try {
    final response = await cloudinary.upload(
      file: uploadData['imagePath'],
      fileBytes: await File(uploadData['imagePath']).readAsBytes(),
      resourceType: CloudinaryResourceType.image,
      folder: 'trip_images/${uploadData['tripId']}',
    );

    if (response.isSuccessful) {
      String imageUrl = response.secureUrl!;

      await _firestore
          .collection('trips')
          .doc(uploadData['tripId'])
          .collection('images')
          .doc(uploadData['imageId'])
          .set({
        'image_id': uploadData['imageId'],
        'image_url': imageUrl,
        'latitude': uploadData['latitude'],
        'longitude': uploadData['longitude'],
        'timestamp': uploadData['timestamp'],
      });

      final tripsLayer = Provider.of<TripsLayer>(context, listen: false);
      tripsLayer.addImageMarkerFromTripProvider(
        uploadData['imageId'],
        LatLng(uploadData['latitude'], uploadData['longitude']),
        imageUrl,
        context
      );

      // Safely remove from pending uploads
      _pendingImageUploads.removeWhere((upload) => upload['imageId'] == uploadData['imageId']);
      await _updatePendingUploads();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully!'))
      );
    }
  } catch (e) {
    print("❌ Error uploading image: $e");
    if (!_pendingImageUploads.any((upload) => upload['imageId'] == uploadData['imageId'])) {
      _pendingImageUploads.add(uploadData);
      await _updatePendingUploads();
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Upload failed. Will retry later.'))
    );
  } finally {
    _isUploading = false; // Reset flag after upload completes
    if (_pendingImageUploads.isNotEmpty) {
      _uploadImage(_pendingImageUploads.first, context); // Retry next upload
    }
  }
}

Future<void> _updatePendingUploads() async {
  final prefs = await SharedPreferences.getInstance();
  final pendingUploads = _pendingImageUploads.map((upload) => json.encode(upload)).toList();
  await prefs.setStringList('pending_uploads', pendingUploads);
}


  Future<void> _processPendingUploads() async {
    if (_pendingImageUploads.isEmpty) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) return;

    final uploads = List<Map<String, dynamic>>.from(_pendingImageUploads);
    for (final upload in uploads) {
   
        final BuildContext? ctx = navigatorKey.currentContext;
if (ctx != null) {
  await _uploadImage(upload, ctx);
}

    
    }
  }



   void updateActiveTripOnMap() {
    if (_currentTrip != null && _isRecording) {
      notifyListeners();
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

    _saveTripTimer?.cancel();

    String tripId = await _saveTripToFirestore();
    await addTripToUser(_currentTrip!.userId, tripId);

    for (String collaboratorId in _currentTrip!.collaborators) {
      if (collaboratorId != _currentTrip!.userId) {
        await addTripToUser(collaboratorId, tripId);
      }
    }

    // Clear stored trip data
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('current_trip');

    final mapController = Provider.of<MapController>(
      navigatorKey.currentState!.overlay!.context,
      listen: false,
    );
    mapController.clearLayer("trips_layer");

    _currentTrip = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _uploadRetryTimer?.cancel();
    _saveTripTimer?.cancel();
    super.dispose();
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



  Stream<List<Map<String, dynamic>>> getTripImagesStream(String tripId) {
  return FirebaseFirestore.instance
      .collection('trips')
      .doc(tripId)
      .collection('images')
      .snapshots()
      .map((snapshot) => snapshot.docs.map((doc) => doc.data()).toList());
}


}