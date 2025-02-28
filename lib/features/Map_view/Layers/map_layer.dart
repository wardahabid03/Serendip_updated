// lib/features/Map_view/layers/map_layer.dart
import 'package:google_maps_flutter/google_maps_flutter.dart';

abstract class MapLayer {
  Set<Marker> getMarkers();
  Set<Polyline> getPolylines();
  Set<Circle> getCircles();
  void onTap(LatLng position);
  void clear();
}
