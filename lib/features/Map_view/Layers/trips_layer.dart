import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serendip/core/constant/colors.dart';
import '../../../core/utils/image_markers.dart';
import '../../../core/utils/marker_utils.dart';
import '../../Trip_Tracking/provider/trip_provider.dart';
import 'map_layer.dart';
import 'package:provider/provider.dart';

class TripsLayer extends MapLayer {
  final Map<String, Polyline> _tripPolylines = {};
  final Map<String, Marker> _tripMarkers = {};
  final Map<String, Circle> _tripCircles = {};
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _imageStreamSubscription;
  StreamSubscription? _activeTripsSubscription;
  Timer? _circleAnimationTimer;
  final userId = FirebaseAuth.instance.currentUser?.uid;

  TripsLayer() {
    _listenToActiveTrips();
  }

  void _listenToActiveTrips() {
    _activeTripsSubscription?.cancel();
    _activeTripsSubscription = _firestore
        .collection('trips')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        final tripData = change.doc.data() as Map<String, dynamic>;
        if (change.type == DocumentChangeType.added || 
            change.type == DocumentChangeType.modified) {
          if (tripData['collaborators']?.contains(userId) ?? false || tripData['user_id'] == userId) {
            _handleActiveTripUpdate(tripData, change.doc.id);
          }
        }
      }
    });
  }


  void listenToCollaborativeTrips(String userId) {
  _activeTripsSubscription?.cancel();
  _activeTripsSubscription = _firestore
    .collection('trips')
    .where('collaborators', arrayContains: userId)
    .where('isActive', isEqualTo: true)
    .snapshots()
    .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.modified) {
          final tripData = change.doc.data() as Map<String, dynamic>;
          _handleActiveTripUpdate(tripData, change.doc.id);
        }
      }
    });
}

Future<void> _handleActiveTripUpdate(Map<String, dynamic> tripData, String tripId) async {
  if (tripData['tripPath'] != null) {
    final List<dynamic> pathData = tripData['tripPath'];
    final List<LatLng> path = pathData.map((point) => 
      LatLng(point['latitude'], point['longitude'])
    ).toList();

    await addTripPolyline(path, tripId);
    
    if (tripData['isActive'] == true && path.isNotEmpty) {
      addRecordingTripEffect(path.last, null);
    }
  }
}


  @override
  Set<Marker> getMarkers() => _tripMarkers.values.toSet();

  @override
  Set<Polyline> getPolylines() => _tripPolylines.values.toSet();

  @override
  Set<Circle> getCircles() => _tripCircles.values.toSet();

  void listenForTripImages(String tripId, BuildContext context) {
    _imageStreamSubscription?.cancel();
    _imageStreamSubscription = _firestore
        .collection('trips')
        .doc(tripId)
        .collection('images')
        .snapshots()
        .listen((snapshot) {
      for (var change in snapshot.docChanges) {
        if (change.type == DocumentChangeType.added) {
          final imageData = change.doc.data()!;
          final location = LatLng(
            imageData['latitude'],
            imageData['longitude'],
          );
          addImageMarker(context, location, imageData['image_url']);


          print("trup Images");
        }
      }
    });
  }

  Future<void> addImageMarker(BuildContext context, LatLng location, String imageUrl) async {
    try {
      final BitmapDescriptor customIcon = await CustomMarkerHelper.getCustomMarker(imageUrl);
      final markerId = MarkerId('image_${DateTime.now().millisecondsSinceEpoch}');
      
      final marker = Marker(
        markerId: markerId,
        position: location,
        icon: customIcon,
        infoWindow: InfoWindow(title: "Trip Image", snippet: "Tap to view"),
        onTap: () {
          showDialog(
            context: context,
            builder: (context) => Dialog(
              child: Image.network(imageUrl,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Center(child: CircularProgressIndicator());
                },
                errorBuilder: (context, error, stackTrace) {
                  return Icon(Icons.error);
                },
              ),
            ),
          );
        },
      );

      _tripMarkers[markerId.value] = marker;
      notifyListeners();
    } catch (e) {
      print("❌ Error adding image marker: $e");
    }
  }

  Future<void> addTripPolyline(List<LatLng> path, String tripId) async {

print("Display Polyline");


    if (path.isEmpty) return;


    print("Trip path not empty");

    final startIcon = await getCustomIcon("assets/images/pin2.png");
    final endIcon = await getCustomIcon("assets/images/pin.png");

    _tripPolylines[tripId] = Polyline(
      polylineId: PolylineId(tripId),
      points: path,
      color: Colors.red,
      width: 6,
    );

    _tripMarkers["start_$tripId"] = Marker(
      markerId: MarkerId("start_$tripId"),
      position: path.first,
      infoWindow: InfoWindow(title: "Trip Start"),
      icon: startIcon,
    );

    if (path.length > 1) {
      _tripMarkers["end_$tripId"] = Marker(
        markerId: MarkerId("end_$tripId"),
        position: path.last,
        infoWindow: InfoWindow(title: "Current Position"),
        icon: endIcon,
      );
    }
print("Added polylines and markers");
    notifyListeners();
  }

  Future<void> updateTripPolyline(List<LatLng> path, String tripId, GoogleMapController mapController) async {
    if (path.isEmpty) return;

    final startIcon = await getCustomIcon("assets/images/pin2.png");

    _tripPolylines[tripId] = Polyline(
      polylineId: PolylineId(tripId),
      points: path,
      color: Colors.blue,
      width: 6,
    );

    _tripMarkers["start_$tripId"] = Marker(
      markerId: MarkerId("start_$tripId"),
      position: path.first,
      infoWindow: InfoWindow(title: "Trip Start"),
      icon: startIcon,
    );

    if (path.length > 1) {
      animatePolylineMovement(path[path.length - 2], path.last, tripId);
    }

    notifyListeners();
  }

  void animatePolylineMovement(LatLng from, LatLng to, String tripId) {
    const int steps = 10;
    const Duration duration = Duration(milliseconds: 500);
    double latStep = (to.latitude - from.latitude) / steps;
    double lngStep = (to.longitude - from.longitude) / steps;
    
    int count = 0;
    Timer.periodic(Duration(milliseconds: duration.inMilliseconds ~/ steps), (timer) {
      if (count >= steps) {
        timer.cancel();
        return;
      }

      LatLng intermediatePoint = LatLng(
        from.latitude + latStep * count,
        from.longitude + lngStep * count
      );
      
      if (_tripPolylines.containsKey(tripId)) {
        List<LatLng> updatedPoints = List.from(_tripPolylines[tripId]!.points)
          ..add(intermediatePoint);
        _tripPolylines[tripId] = _tripPolylines[tripId]!
          .copyWith(pointsParam: updatedPoints);
        notifyListeners();
      }

      count++;
    });
  }

  void addRecordingTripEffect(LatLng position, GoogleMapController? mapController) {
    String circleId = "recording_trip_circle";

    _tripCircles[circleId] = Circle(
      circleId: CircleId(circleId),
      center: position,
      radius: 100,
      fillColor: tealColor.withOpacity(0.5),
      strokeColor: Colors.red,
      strokeWidth: 2,
    );

    _circleAnimationTimer?.cancel();
    animateCircleExpansion(circleId);
    notifyListeners();
  }

  void animateCircleExpansion(String circleId) {
    double radius = 100;
    _circleAnimationTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      radius = (radius == 100) ? 80 : 100;
      if (_tripCircles.containsKey(circleId)) {
        _tripCircles[circleId] = _tripCircles[circleId]!
          .copyWith(radiusParam: radius);
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }

  @override
  void clear() {
    _tripPolylines.clear();
    _tripMarkers.clear();
    _tripCircles.clear();
    _circleAnimationTimer?.cancel();
    _imageStreamSubscription?.cancel();
    _activeTripsSubscription?.cancel();
    notifyListeners();
  }

  @override
  void onTap(LatLng position) {}

  @override
  void dispose() {
    _imageStreamSubscription?.cancel();
    _activeTripsSubscription?.cancel();
    _circleAnimationTimer?.cancel();
    super.dispose();
  }
}
