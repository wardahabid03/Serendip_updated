import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/Map_view/controller/map_controller.dart';

class SharedMapWidget extends StatelessWidget {
  final LatLng initialPosition;
  final double initialZoom;

  const SharedMapWidget({
    Key? key,
    required this.initialPosition,
    this.initialZoom = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<MapController>(
      builder: (context, controller, child) {
        final markers = controller.markers;
        print("🗺 SharedMapWidget: Rebuilding with ${markers.length} markers");

        return GoogleMap(
          initialCameraPosition: CameraPosition(
            target: initialPosition,
            zoom: initialZoom,
          ),
          markers: markers,
          polylines: controller.polylines,
          circles: controller.circles,
          onMapCreated: (GoogleMapController mapController) {
            controller.setController(mapController);
          },
           tiltGesturesEnabled: true, // Ensure tilt gestures are enabled
          myLocationEnabled: true,
          myLocationButtonEnabled: true,
          zoomControlsEnabled: true,
          mapType: MapType.normal,
        );
      },
    );
  }
}
