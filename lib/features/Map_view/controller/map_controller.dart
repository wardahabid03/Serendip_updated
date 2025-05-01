import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:serendip/features/Map_view/Layers/ad_layer.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import shared_preferences
import '../Layers/map_layer.dart';
import '../Layers/trips_layer.dart';
import '../Layers/review_layer.dart';


class MapController extends ChangeNotifier {
  GoogleMapController? _controller;
  final Map<String, MapLayer> _layers = {};
  final Set<String> _activeLayers = {};
  TripsLayer _tripsLayer;
  final ReviewLayer _reviewLayer;
  final AdLayer _adsLayer; // ✅ Add AdsLayer reference
  Circle? _activeTripCircle;

  MapController(this._tripsLayer, this._reviewLayer, this._adsLayer) {
    _tripsLayer.addListener(_onLayerChanged);
    _reviewLayer.addListener(_onLayerChanged);
    _adsLayer.addListener(_onLayerChanged); // ✅ Listen for ads layer updates
    addLayer('trips_layer', _tripsLayer);
    addLayer('reviews_layer', _reviewLayer);
    addLayer('ads_layer', _adsLayer); // ✅ Register AdsLayer
    _activeLayers.add('trips_layer'); // Enable trips by default

    // Load review visibility setting from SharedPreferences
    _loadReviewVisibility();
  }

  // Fetch the review visibility setting from SharedPreferences
  Future<void> _loadReviewVisibility() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    bool reviewVisibility = prefs.getBool('reviewVisibility') ?? true; // Default to true if not set
    toggleReviewLayer(reviewVisibility);
  }

  void updateTripsLayer(TripsLayer newTripsLayer) {
    if (_tripsLayer != newTripsLayer) {
      _tripsLayer.removeListener(_onLayerChanged);
      _tripsLayer = newTripsLayer;
      _tripsLayer.addListener(_onLayerChanged);
      notifyListeners();
    }
  }

  void _onLayerChanged() {
    print("🔄 Layer changed, notifying listeners");
    Future.microtask(() => notifyListeners()); // Ensure UI updates on next frame
  }

  void setController(GoogleMapController controller) {
    _controller = controller;
    notifyListeners();
  }

  GoogleMapController? get controller => _controller;

  void addLayer(String layerId, MapLayer layer) {
    if (!_layers.containsKey(layerId)) {
      _layers[layerId] = layer;
      layer.addListener(_onLayerChanged);
    }
    notifyListeners();
  }

  void toggleReviewLayer(bool active) {
    toggleLayer('reviews_layer', active);
    _reviewLayer.setActive(active);
  }

  // Add ADS_LAYER toggle functionality
  void toggleAdsLayer(bool active) {
    toggleLayer('ads_layer', active);
  
  }

  MapLayer? getLayer(String layerId) => _layers[layerId];

  void toggleLayer(String layerId, bool active) {
    if (active) {
      _activeLayers.add(layerId);
      print("Added $layerId");
    } else {
      _activeLayers.remove(layerId);
      print("Removed $layerId");
    }
    notifyListeners();
  }

  Set<Marker> get markers {
    Set<Marker> allMarkers = {};
    for (var layerId in _activeLayers) {
      final layerMarkers = _layers[layerId]?.getMarkers() ?? {};
      print("📍 Layer $layerId has ${layerMarkers.length} markers");
      allMarkers.addAll(layerMarkers);
    }
    print("📍 Total markers: ${allMarkers.length}");
    return allMarkers;
  }

  Set<Polyline> get polylines {
    Set<Polyline> allPolylines = {};
    for (var layerId in _activeLayers) {
      allPolylines.addAll(_layers[layerId]?.getPolylines() ?? {});
    }
    return allPolylines;
  }

  Set<Circle> get circles {
    Set<Circle> allCircles = {};
    if (_activeTripCircle != null) allCircles.add(_activeTripCircle!);
    for (var layerId in _activeLayers) {
      allCircles.addAll(_layers[layerId]?.getCircles() ?? {});
    }
    return allCircles;
  }

  // Smooth camera movement with tilt and rotation
  Future<bool> moveCamera(LatLng target, {double zoom = 15, double tilt = 0, double bearing = 0}) async {
    if (_controller == null) {
      print("❌ Map controller is null");
      return false;
    }

    try {
      print("🎯 Smoothly moving camera to: ${target.latitude}, ${target.longitude} with tilt: $tilt and zoom: $zoom");

      await _controller!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: target,
            zoom: zoom,
            tilt: tilt,
            bearing: bearing,
          ),
        ),
      );

      print("✅ Camera animation completed");
      return true;
    } catch (e) {
      print("❌ Error moving camera: $e");
      return false;
    }
  }

  // Add Trip Polyline
  void addTripPolyline(List<LatLng> path, String tripId) {
    _tripsLayer.addTripPolyline(path, tripId);
  }

  // Add Active Trip Circle
  void addActiveTripCircle(LatLng position) {
    _activeTripCircle = Circle(
      circleId: const CircleId("active_trip"),
      center: position,
      radius: 10,
      fillColor: Colors.red.withOpacity(0.5),
      strokeColor: Colors.red,
      strokeWidth: 2,
    );
    notifyListeners();
  }

  // Clear all trips
  void clearAllTrips() {
    _tripsLayer.clear();
  }

  // Clear specific layer
  void clearLayer(String layerId) {
    _layers[layerId]?.clear();
    notifyListeners();
  }

  // Clear all layers
  void clearAllLayers() {
    for (var layer in _layers.values) {
      layer.clear();
    }
    notifyListeners();
  }

  // Save review visibility setting to SharedPreferences
  Future<void> saveReviewVisibility(bool value) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reviewVisibility', value);
  }

  void clearActiveTripOverlay() {
  _activeTripCircle = null; // Removes the active trip circle
  notifyListeners(); // Notify listeners to update the UI
}


  @override
  void dispose() {
    for (var layer in _layers.values) {
      layer.removeListener(_onLayerChanged);
    }
    _controller?.dispose();
    super.dispose();
  }

  TripsLayer get tripsLayer => _tripsLayer;
  ReviewLayer get reviewLayer => _reviewLayer;
  AdLayer get adsLayer => _adsLayer; // ✅ Expose the AdsLayer
}
