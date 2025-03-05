
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:serendip/models/trip_model.dart';
import 'package:serendip/core/utils/geojson_utils.dart';
import 'package:uuid/uuid.dart';

import '../../../core/utils/navigator_key.dart';
import '../../Map_view/controller/map_controller.dart';

class TripProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
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


  /// **Add trip ID to a user's document in Firestore**
Future<void> addTripToUser(String userId, String tripId) async {
  final userRef = _firestore.collection('users').doc(userId);

  await userRef.update({
    'trips': FieldValue.arrayUnion([tripId]),
    'tripCount': FieldValue.increment(1),
  });
}


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



  /// **Stop the trip and save it**
  Future<void> stopTrip(LatLng endLocation) async {
  if (_currentTrip == null) return;

  _isRecording = false;
  _tripPath.add(endLocation);
  _currentTrip!.tripPath = _tripPath;
  _currentTrip!.isActive = false;

  String tripId = await _saveTripToFirestore();

  await addTripToUser(_currentTrip!.userId, tripId);
  for (String collaboratorId in _currentTrip!.collaborators) {
    await addTripToUser(collaboratorId, tripId);
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


  /// **Update polylines and markers for UI updates**
  void _updateMapElements() {
    if (_tripPath.isEmpty) return;
    
    // Create polyline for the active trip
    _polylines.clear();
    _polylines.add(
      Polyline(
        polylineId: PolylineId("active_trip"),
        points: _tripPath,
        color: Colors.blue,
        width: 5,
      ),
    );

    // Update marker to show current location
    _markers.clear();
    _markers.add(
      Marker(
        markerId: MarkerId("current_location"),
        position: _tripPath.last,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ),
    );
  }

  /// **Save the trip to Firestore**
  Future<String> _saveTripToFirestore() async {
    if (_currentTrip == null) return '';

    final tripMap = _currentTrip!.toMap();
    tripMap['trip_path'] = GeoJSONUtils.latLngListToGeoJSONString(_currentTrip!.tripPath);

    await _firestore.collection('trips').doc(_currentTrip!.tripId).set(tripMap);
    return _currentTrip!.tripId;
  }

  /// **Fetch trips based on filter criteria**
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
      final tripDoc = await FirebaseFirestore.instance.collection('trips').doc(tripId).get();
      if (!tripDoc.exists) return null;

      final data = tripDoc.data();
      if (data == null) return null;

      return TripModel.fromMap(data, tripDoc.id);
    } catch (e) {
      return null;
    }
  }
  /// **Updates active trip UI on the map**
void updateActiveTripOnMap() {
  if (_currentTrip != null && _isRecording) {
    notifyListeners();
  }
}

}