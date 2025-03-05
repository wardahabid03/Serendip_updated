import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

abstract class MapLayer extends ChangeNotifier { // ✅ Extend ChangeNotifier
  Set<Marker> getMarkers();
  Set<Polyline> getPolylines();
  Set<Circle> getCircles();

  void clear();
  void onTap(LatLng position);
}
