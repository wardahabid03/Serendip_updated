// lib/services/marker_service.dart

import 'package:google_maps_flutter/google_maps_flutter.dart';

class MarkerService {
  static void addMarker(
    Set<Marker> markers,
    LatLng position,
    String title,
    Map<String, dynamic> placeData,
    Function(LatLng) onTapCallback,
  ) {
    final marker = Marker(
      markerId: MarkerId(title),
      position: position,
      infoWindow: InfoWindow(
        title: title,
        snippet: placeData['district'],
        onTap: () => onTapCallback(position),
      ),
    );
    markers.add(marker);
  }
}
