import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../Layers/map_layer.dart';
import '../Layers/trips_layer.dart';

class MapController extends ChangeNotifier {
  GoogleMapController? _controller; // ✅ Keep this consistent throughout
  final Map<String, MapLayer> _layers = {};
  final Set<String> _activeLayers = {};
  TripsLayer _tripsLayer;
  Circle? _activeTripCircle;

  // ✅ Constructor now requires TripsLayer to avoid unnecessary re-initialization
  MapController(this._tripsLayer) {
    _tripsLayer.addListener(_onLayerChanged);
    addLayer('trips_layer', _tripsLayer);
    _activeLayers.add('trips_layer');
  }

  void updateTripsLayer(TripsLayer newTripsLayer) {
    if (_tripsLayer != newTripsLayer) {
      _tripsLayer.removeListener(_onLayerChanged);
      _tripsLayer = newTripsLayer;
      _tripsLayer.addListener(_onLayerChanged);
      notifyListeners();
    }
  }

  // ✅ Ensures UI updates correctly when markers change
  void _onLayerChanged() {
    print("🔄 Layer changed, notifying listeners");
    notifyListeners();
  }

  void setController(GoogleMapController controller) {
    _controller = controller;
    notifyListeners();
  }

  GoogleMapController? get controller => _controller; // ✅ Getter for `_controller`

  void addLayer(String layerId, MapLayer layer) {
    if (!_layers.containsKey(layerId)) {
      _layers[layerId] = layer;
      layer.addListener(_onLayerChanged);
    }
    notifyListeners();
  }

  MapLayer? getLayer(String layerId) => _layers[layerId];

  void toggleLayer(String layerId, bool active) {
    if (active) {
      _activeLayers.add(layerId);
    } else {
      _activeLayers.remove(layerId);
    }
    notifyListeners();
  }

  // ✅ Updated markers to ensure correct references
  Set<Marker> get markers {
    Set<Marker> allMarkers = {};
    for (var layerId in _activeLayers) {
      final layerMarkers = _layers[layerId]?.getMarkers() ?? {};
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

  Future<bool> moveCamera(LatLng target, {double zoom = 15}) async {
    if (_controller == null) {
      print("❌ Map controller is null");
      return false;
    }

    try {
      print("🎯 Moving camera to: ${target.latitude}, ${target.longitude}");
      await _controller!.animateCamera(
        CameraUpdate.newLatLngZoom(target, zoom),
      );
      print("✅ Camera moved successfully");
      return true;
    } catch (e) {
      print("❌ Error moving camera: $e");
      return false;
    }
  }

  void addTripPolyline(List<LatLng> path, String tripId) {
    _tripsLayer.addTripPolyline(path, tripId);
  }

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

  void clearAllTrips() {
    _tripsLayer.clear();
  }

  void clearLayer(String layerId) {
    _layers[layerId]?.clear();
  }

  void clearAllLayers() {
    for (var layer in _layers.values) {
      layer.clear();
    }
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
}
