import 'dart:async';
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
  StreamSubscription? _imageStreamSubscription;
  Timer? _circleAnimationTimer;

  @override
  Set<Marker> getMarkers() {
    return _tripMarkers.values.toSet();
  }

  @override
  Set<Polyline> getPolylines() => _tripPolylines.values.toSet();

  @override
  Set<Circle> getCircles() => _tripCircles.values.toSet();

  void listenForTripImages(String tripId, BuildContext context) {
    _imageStreamSubscription?.cancel();
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    _imageStreamSubscription = tripProvider.getTripImagesStream(tripId).listen((images) async {
      for (var image in images) {
        LatLng location = LatLng(image['latitude'], image['longitude']);
        String imageUrl = image['imageUrl'];
        await addImageMarker(context, location, imageUrl);
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
    if (path.isEmpty) return;

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

    _tripMarkers["end_$tripId"] = Marker(
      markerId: MarkerId("end_$tripId"),
      position: path.last,
      infoWindow: InfoWindow(title: "Trip End"),
      icon: endIcon,
    );

    notifyListeners();
  }
Future<void> updateTripPolyline(List<LatLng> path, String tripId, GoogleMapController mapController) async {
  if (path.isEmpty) return;

  final startIcon = await getCustomIcon("assets/images/pin2.png");

  if (_tripPolylines.containsKey(tripId)) {
    List<LatLng> currentPoints = _tripPolylines[tripId]!.points;
    if (currentPoints.isNotEmpty) {
      LatLng lastPoint = currentPoints.last;
      LatLng newPoint = path.last;

      // Animate the movement
      animatePolylineMovement(lastPoint, newPoint, tripId);
    }
  }

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

  notifyListeners();
}

// Function to animate the polyline movement
void animatePolylineMovement(LatLng from, LatLng to, String tripId) {
  const int steps = 10; // Number of animation steps
  const Duration duration = Duration(milliseconds: 500); // Animation duration
  double latStep = (to.latitude - from.latitude) / steps;
  double lngStep = (to.longitude - from.longitude) / steps;
  
  int count = 0;
  Timer.periodic(Duration(milliseconds: duration.inMilliseconds ~/ steps), (timer) {
    if (count >= steps) {
      timer.cancel();
      return;
    }

    LatLng intermediatePoint = LatLng(from.latitude + latStep * count, from.longitude + lngStep * count);
    if (_tripPolylines.containsKey(tripId)) {
      List<LatLng> updatedPoints = List.from(_tripPolylines[tripId]!.points)..add(intermediatePoint);
      _tripPolylines[tripId] = _tripPolylines[tripId]!.copyWith(pointsParam: updatedPoints);
      notifyListeners();
    }

    count++;
  });
}


void _animatePolylineUpdate(LatLng lastPoint, List<LatLng> newPath, String tripId) {
  List<LatLng> animatedPath = [..._tripPolylines[tripId]?.points ?? []];
  int index = 0;

  Timer.periodic(Duration(milliseconds: 200), (timer) {
    if (index < newPath.length) {
      animatedPath.add(newPath[index]);
      _tripPolylines[tripId] = _tripPolylines[tripId]!.copyWith(pointsParam: animatedPath);
      notifyListeners();
      index++;
    } else {
      timer.cancel(); // Stop when all points are added
    }
  });
}


void addRecordingTripEffect(LatLng position, GoogleMapController mapController) {
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
        _tripCircles[circleId] = _tripCircles[circleId]!.copyWith(radiusParam: radius);
        notifyListeners();
      } else {
        timer.cancel();
      }
    });
  }




  void addImageMarkerFromTripProvider(String imageId, LatLng location, String imageUrl, BuildContext context) async {

    print("image kaey");
  if (_tripMarkers.containsKey(imageId)) return; // Prevent duplicate markers

print("+");
  try {
    final BitmapDescriptor customIcon = await CustomMarkerHelper.getCustomMarker(imageUrl);

    print("++");
    
    final marker = Marker(
      markerId: MarkerId(imageId),
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
 print("+++");
    _tripMarkers[imageId] = marker;
    getMarkers();
    notifyListeners();
  } catch (e) {
    print("❌ Error adding image marker: $e");
  }
}


  void stopRecordingTripEffect() {
    _circleAnimationTimer?.cancel();
    _tripCircles.clear();
    notifyListeners();
  }

  @override
  void clear() {
    _tripPolylines.clear();
    _tripMarkers.clear();
    _tripCircles.clear();
    _circleAnimationTimer?.cancel();
    _imageStreamSubscription?.cancel();
    notifyListeners();
  }

  @override
  void onTap(LatLng position) {}
}
