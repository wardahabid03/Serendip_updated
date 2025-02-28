import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:serendip/models/trip_model.dart';
import 'package:serendip/core/utils/geojson_utils.dart';
import 'package:uuid/uuid.dart';

class TripProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  TripModel? _currentTrip;
  bool _isRecording = false;
  List<LatLng> _tripPath = [];
  List<TripModel> _trips = [];

  TripModel? get currentTrip => _currentTrip;
  bool get isRecording => _isRecording;
  List<TripModel> get trips => _trips;

  void startTrip(String tripName, String userId, String description, String privacy, List<String> collaborators, LatLng startLocation) {
    _tripPath.clear();
    _isRecording = true;
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
    _tripPath.add(startLocation);
    notifyListeners();
  }

  void addLocation(LatLng location) {
    if (_isRecording) {
      _tripPath.add(location);
      notifyListeners();
    }
  }

  Future<void> stopTrip(LatLng endLocation) async {
    if (_currentTrip == null) return;

    _isRecording = false;
    _tripPath.add(endLocation);
    _currentTrip!.tripPath = _tripPath;
    _currentTrip!.isActive = false;

    String tripId = await _saveTripToFirestore();
    await addTripToUser(_currentTrip!.userId, tripId);

    _currentTrip = null;
    notifyListeners();
  }

  Future<String> _saveTripToFirestore() async {
    if (_currentTrip == null) return '';

    final tripMap = _currentTrip!.toMap();
    tripMap['trip_path'] = GeoJSONUtils.latLngListToGeoJSONString(_currentTrip!.tripPath);

    await _firestore.collection('trips').doc(_currentTrip!.tripId).set(tripMap);
    return _currentTrip!.tripId;
  }

  Future<void> addTripToUser(String userId, String tripId) async {
    final userRef = FirebaseFirestore.instance.collection('users').doc(userId);

    await userRef.update({
      'trips': FieldValue.arrayUnion([tripId]),
      'tripCount': FieldValue.increment(1),
    });
  }

 /// Fetch trips based on filter criteria
Future<void> fetchTrips({required String userId, required String filter}) async {
  QuerySnapshot tripSnapshot;

  if (filter == 'My Trips') {
    tripSnapshot = await _firestore
        .collection('trips')
        .where('user_id', isEqualTo: userId)
        .get();
  } 
  
  else if (filter == 'Friends\' Trips') {
    List<String> friends = [];

    // Fetch friends' IDs from the 'friends' subcollection
    final friendsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .get();

    friends = friendsSnapshot.docs.map((doc) => doc.id).toList();

    print("Fetched Friends' IDs: $friends");

    if (friends.isNotEmpty) {
      // Fetch only friends' trips with privacy "friends" or "public"
      tripSnapshot = await _firestore
          .collection('trips')
          .where('user_id', whereIn: friends)
          .where('privacy', whereIn: ['friends', 'public']) // Filter privacy
          .get();
    } else {
      print("No friends found, skipping trips fetch.");
      return;
    }
  } 
  
  else {
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
 
}



