import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

abstract class MapLayer extends ChangeNotifier {
  Set<Marker> getMarkers();
  Set<Polyline> getPolylines();
  Set<Circle> getCircles();
  void clear();
  void onTap(LatLng position);
}