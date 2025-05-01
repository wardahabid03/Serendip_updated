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
import 'package:serendip/services/location_service.dart';
import 'package:uuid/uuid.dart';
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import '../../../core/utils/navigator_key.dart';
import '../../Map_view/Layers/trips_layer.dart';
import '../../Map_view/controller/map_controller.dart';
import '../../location/location_provider.dart';

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

  final List<Map<String, dynamic>> _uploadQueue = [];
  bool _isProcessingQueue = false;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

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
    _pendingImageUploads.addAll(pendingUploads
        .map((upload) => json.decode(upload) as Map<String, dynamic>));
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

  void startTrip(String tripName, String userId, String description,
    String privacy, List<String> collaborators, LatLng startLocation) async {
  print("🚀 startTrip() called in TripProvider!");

  _tripPath.clear();
  _isRecording = true;

  if (!collaborators.contains(userId)) {
    collaborators.add(userId);
  }

  final tripId = const Uuid().v4();

  _currentTrip = TripModel(
    tripId: tripId,
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
   await addTripToUser(_currentTrip!.userId, tripId);

    for (String collaboratorId in _currentTrip!.collaborators) {
      if (collaboratorId != _currentTrip!.userId) {
        await addTripToUser(collaboratorId, tripId);
      }
    }


  // Save trip immediately to Firestore
  await _firestore.collection('trips').doc(tripId).set(_currentTrip!.toMap());

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

void addLocation(LatLng location) async {
  if (_isRecording) {
    // Check if the current user is the creator of the trip
    final currentUserId = getCurrentUserId();
    if (_currentTrip?.userId != currentUserId) {
      // If the current user is not the creator, do not add the location
      print("🚫 Current user is not the trip creator. Skipping location.");
      return;
    }

    await updateTripPath(location);

    final mapController = Provider.of<MapController>(
      navigatorKey.currentState!.overlay!.context,
      listen: false,
    );

    mapController.addTripPolyline(_tripPath, "active_trip");
    mapController.addActiveTripCircle(location);
  }
}



Future<void> checkAndSetActiveCollaborativeTrip() async {
  final userId = getCurrentUserId();
  if (userId == null) return;

  final snapshot = await _firestore
      .collection('trips')
      .where('collaborators', arrayContains: userId)
      .where('isActive', isEqualTo: true)
      .get();

  if (snapshot.docs.isNotEmpty) {
    final data = snapshot.docs.first.data();
    final tripId = snapshot.docs.first.id;
    _currentTrip = TripModel.fromMap(data, tripId);
    _tripPath = _currentTrip!.tripPath;
    _isRecording = true;
    notifyListeners();

    print("✅ Collaborative trip loaded: ${_currentTrip!.tripName}");
  }
}



Future<void> captureImage(File imageFile, BuildContext context) async {
  print("📸 Starting captureImage...");

  if (_currentTrip == null) {
    print("⚠️ No active trip to save the image.");
    return;
  }

  final currentUserId = getCurrentUserId();
  print("👤 Current user ID: $currentUserId");

  if (currentUserId == null) {
    print("❌ No logged-in user.");
    return;
  }

  if (!_currentTrip!.collaborators.contains(currentUserId)) {
    print("❌ User $currentUserId not authorized to add images to this trip.");
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('You are not a collaborator for this trip.')),
    );
    return;
  }

  try {
    print("📍 Getting current location...");
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final LatLng? location = locationProvider.currentLocation;
    print("📍 Location fetched: ${location?.latitude}, ${location?.longitude}");

    if (location == null) {
      print("❌ Current location not available.");
      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Location not available. Try again.')),
      );
      return;
    }

    final imageId = const Uuid().v4();
    print("🆔 Generated image ID: $imageId");

    final directory = await getApplicationDocumentsDirectory();
    final savedImagePath = '${directory.path}/$imageId.jpg';
    print("💾 Saving image to: $savedImagePath");

    await imageFile.copy(savedImagePath);
    print("✅ Image copied to local path");

    final uploadData = {
      'imageId': imageId,
      'imagePath': savedImagePath,
      'tripId': _currentTrip!.tripId,
      'latitude': location.latitude,
      'longitude': location.longitude,
      'timestamp': DateTime.now().toIso8601String(),
      'uploadedBy': currentUserId,
    };

    print("📦 Upload data prepared: $uploadData");

    _uploadQueue.add(uploadData);
    print("📥 Added to upload queue. Queue length: ${_uploadQueue.length}");

    _saveQueueToPrefs();
    print("📁 Queue saved to prefs");

    _triggerQueueProcessing();
    print("🚀 Triggered queue processing");

    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Image saved and queued for upload')),
    );
  } catch (e) {
    print("❌ Error in captureImage: $e");
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('Error saving image: ${e.toString()}')),
    );
  }
}




void _triggerQueueProcessing() {
  if (_isProcessingQueue) return;
  _processQueue();
}

Future<void> _processQueue() async {
  _isProcessingQueue = true;

  while (_uploadQueue.isNotEmpty) {
    final uploadData = _uploadQueue.first;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity == ConnectivityResult.none) {
      print("📴 Offline. Pausing queue.");
      break;
    }

    try {
      final ctx = navigatorKey.currentContext;
      if (ctx == null) {
        print("❌ Context is null. Can't upload.");
        break;
      }

      await Future.delayed(const Duration(milliseconds: 300)); // give UI time
      await _uploadImage(uploadData, ctx);

      _uploadQueue.removeAt(0);
      _saveQueueToPrefs();
    } catch (e) {
      print("❌ Upload failed, keeping in queue: $e");
      break; // Don't remove, keep for retry
    }
  }

  _isProcessingQueue = false;
}

Future<void> _saveQueueToPrefs() async {
  final prefs = await SharedPreferences.getInstance();
  final list = _uploadQueue.map((e) => json.encode(e)).toList();
  await prefs.setStringList('upload_queue', list);
}



// Updated _uploadImage remains mostly unchanged
Future<void> _uploadImage(Map<String, dynamic> uploadData, BuildContext context) async {
  print("🚀 Starting image upload...");
  try {
    final filePath = uploadData['imagePath'];
    final fileBytes = await File(filePath).readAsBytes();

    final response = await cloudinary.upload(
      file: filePath,
      fileBytes: fileBytes,
      resourceType: CloudinaryResourceType.image,
      folder: 'trip_images/${uploadData['tripId']}',
    );

    if (response.isSuccessful) {
      final imageUrl = response.secureUrl!;
      print("✅ Image uploaded to Cloudinary: $imageUrl");

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
        'uploadedBy': uploadData['uploadedBy'],
      });

      final tripsLayer = Provider.of<TripsLayer>(context, listen: false);
      tripsLayer.addImageMarker(
        uploadData['imageId'],
        LatLng(uploadData['latitude'], uploadData['longitude']),
        imageUrl,
     
      );

      _pendingImageUploads.removeWhere((upload) => upload['imageId'] == uploadData['imageId']);
      await _updatePendingUploads();

      scaffoldMessengerKey.currentState?.showSnackBar(
        const SnackBar(content: Text('Image uploaded successfully!')),
      );
    } else {
      throw Exception("Cloudinary upload failed: ${response.error}");
    }
  } catch (e) {
    print("🚨 Upload error: $e");

    if (!_pendingImageUploads.any((upload) => upload['imageId'] == uploadData['imageId'])) {
      _pendingImageUploads.add(uploadData);
      await _updatePendingUploads();
    }

    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(content: Text('Upload failed. Will retry later.')),
    );
    throw e; // rethrow to keep item in queue
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
    tripMap['trip_path'] =
        GeoJSONUtils.latLngListToGeoJSONString(_currentTrip!.tripPath);

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

  Future<void> updateTripPath(LatLng newLocation) async {
  if (!_isRecording || _currentTrip == null) return;

  _tripPath.add(newLocation);
  _currentTrip!.tripPath.add(newLocation);

  // Update Firestore in real-time
  await _firestore.collection('trips').doc(_currentTrip!.tripId).update({
    'tripPath': _tripPath.map((point) => {
      'latitude': point.latitude, 
      'longitude': point.longitude
    }).toList(),
    'lastUpdated': FieldValue.serverTimestamp(),
  });

  notifyListeners();
}


  Future<void> fetchTrips(
      {required String userId, required String filter}) async {
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
            .where('privacy', whereIn: ['friends', 'public']).get();
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
        .map((doc) =>
            TripModel.fromMap(doc.data() as Map<String, dynamic>, doc.id))
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
      DocumentReference userRef =
          firestore.collection('users').doc(currentUserId);

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
      DocumentReference imageRef = _firestore
          .collection('trips')
          .doc(tripId)
          .collection('images')
          .doc(imageId);

      // Get image data before deleting
      DocumentSnapshot imageSnapshot = await imageRef.get();
      if (!imageSnapshot.exists) return;

      Map<String, dynamic>? imageData =
          imageSnapshot.data() as Map<String, dynamic>?;
      String imageUrl = imageData?['image_url'] ?? '';

      
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
