import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../layers/map_layer.dart';
import '../layers/trips_layer.dart';

class MapController extends ChangeNotifier {
  GoogleMapController? _mapController;
  final Map<String, MapLayer> _layers = {};
  final Set<String> _activeLayers = {};
  final TripsLayer _tripsLayer = TripsLayer();

  MapController() {
    _layers['trips_layer'] = _tripsLayer; // Register trips layer
    _activeLayers.add('trips_layer');
  }

  void setController(GoogleMapController controller) {
    _mapController = controller;
    Future.microtask(() {
      notifyListeners();
    });
    print("Map controller initialized");
  }

  void addLayer(String layerId, MapLayer layer) {
    _layers[layerId] = layer;

    // ✅ Fix: Defer UI updates to avoid Flutter build errors
    Future.microtask(() {
      notifyListeners();
    });
  }

  void toggleLayer(String layerId, bool active) {
    if (active) {
      _activeLayers.add(layerId);
    } else {
      _activeLayers.remove(layerId);
    }

    // ✅ Fix: Ensure safe UI updates
    Future.microtask(() {
      notifyListeners();
    });
  }

  MapLayer? getLayer(String layerId) {
    return _layers[layerId];
  }

  Set<Marker> get markers {
    Set<Marker> allMarkers = {};
    for (var layerId in _activeLayers) {
      allMarkers.addAll(_layers[layerId]?.getMarkers() ?? {});
    }
    return allMarkers;
  }

  Set<Polyline> get polylines {
    Set<Polyline> allPolylines = {};
    for (var layerId in _activeLayers) {
      allPolylines.addAll(_layers[layerId]?.getPolylines() ?? {});
    }
    return allPolylines;
  }

  Future<bool> moveCamera(LatLng target, {double zoom = 15}) async {
    if (_mapController == null) {
      print("Map controller is null");
      return false;
    }

    try {
      print("Moving camera to: ${target.latitude}, ${target.longitude}");
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(target, zoom),
      );
      print("Camera moved successfully");
      return true;
    } catch (e) {
      print("Error moving camera: $e");
      return false;
    }
  }

  // 🔹 Add a trip polyline dynamically
  void addTripPolyline(List<LatLng> path, String tripId) {
    _tripsLayer.addTripPolyline(path, tripId);
    Future.microtask(() {
      notifyListeners();
    });
  }

  // 🔹 Clears all trips from the map
  void clearAllTrips() {
    _tripsLayer.clear();
    Future.microtask(() {
      notifyListeners();
    });
  }

  void clearLayer(String layerId) {
    _layers[layerId]?.clear();
    Future.microtask(() {
      notifyListeners();
    });
  }

  void clearAllLayers() {
    for (var layer in _layers.values) {
      layer.clear();
    }
    Future.microtask(() {
      notifyListeners();
    });
  }
}
