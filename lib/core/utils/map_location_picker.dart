import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class MapLocationPickerScreen extends StatefulWidget {
  const MapLocationPickerScreen({super.key});

  @override
  State<MapLocationPickerScreen> createState() => _MapLocationPickerScreenState();
}

class _MapLocationPickerScreenState extends State<MapLocationPickerScreen> {
  LatLng? pickedLatLng;
  late GoogleMapController _mapController;
  bool _isLoading = true;
  LatLng _initialPosition = const LatLng(33.6844, 73.0479); // Default: Islamabad

  @override
  void initState() {
    super.initState();
    _fetchCurrentLocation();
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final location = Location();
      final locData = await location.getLocation();
      setState(() {
        _initialPosition = LatLng(locData.latitude ?? 33.6844, locData.longitude ?? 73.0479);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Failed to get current location: $e");
      setState(() {
        _isLoading = false; // Still show map with default
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pick Location")),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _initialPosition,
                zoom: 14,
              ),
              onMapCreated: (controller) => _mapController = controller,
              onTap: (LatLng pos) {
                setState(() {
                  pickedLatLng = pos;
                });
              },
              markers: pickedLatLng != null
                  ? {
                      Marker(
                        markerId: const MarkerId('picked-location'),
                        position: pickedLatLng!,
                      )
                    }
                  : {},
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: pickedLatLng != null
            ? () {
                Navigator.pop(
                  context,
                  GeoPoint(pickedLatLng!.latitude, pickedLatLng!.longitude),
                );
              }
            : null,
        label: const Text("Select"),
        icon: const Icon(Icons.check),
        backgroundColor: pickedLatLng != null ? Colors.teal : Colors.grey,
      ),
    );
  }
}
