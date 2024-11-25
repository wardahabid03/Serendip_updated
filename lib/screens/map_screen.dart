import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:serendip/colors.dart';
import 'package:serendip/providers/auth_provider.dart';
import 'package:serendip/routes.dart';
import 'package:serendip/screens/place_details_bottom_sheet.dart';
import '../services/location_service.dart';
import '../services/marker_service.dart';
import '../services/api_service.dart';
import '../models/places.dart'; // Import the Place model

class MapScreen extends StatefulWidget {
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer();
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {}; // Store polyline for the route
  LatLng _userLocation = LatLng(0, 0);
  TextEditingController _searchController = TextEditingController();
  List<Place> _places = [];
  bool _isPlaceSelected = false;
  String _selectedPlaceName = '';
  String _selectedPlaceDescription = '';
  String _selectedPlaceImageUrl = '';
  LatLng _selectedPlaceLocation = LatLng(0, 0);
  String _selectedPlaceCategory1 = '';
  String _selectedPlaceCategory2 = '';
  String _selectedPlaceCategory3 = '';
  double _containerHeight = 0.5;
  bool _isMapReady = false;
  LatLng Location= LatLng(0, 0);
  double zoom=12;



  @override
  void initState() {
    super.initState();
    _getUserLocation();
  }

  Future<void> _getUserLocation() async {
    LatLng userLocation = await LocationService.getUserLocation();
    setState(() {
      _userLocation = userLocation;
      Location=userLocation;
    });
    _goToLocation(_userLocation);
  }

  Future<void> _goToLocation(LatLng target, {double zoom = 12}) async {
    try {
      print('gotolocation');
      if (!_isMapReady) return; // Ensure map is ready
      print(10);
      final GoogleMapController controller = await _controller.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: zoom),
        ),
      );

setState(() {
  zoom=4;
  Location=target;
});

    } catch (e) {
      print("Failed to animate camera: $e");
    }
  }

  Future<void> _searchPlaces() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;

    final recommendations = await ApiService.fetchRecommendations(query);
    if (recommendations != null) {
      setState(() {
        _places = recommendations;
        _markers.clear();
        _isPlaceSelected = false;
      });

      for (var place in _places) {
        LatLng placeLatLng = LatLng(place.latitude, place.longitude);
        _markers.add(
          Marker(
            markerId: MarkerId(place.name),
            position: placeLatLng,
            infoWindow: InfoWindow(title: place.name),
          ),
        );
      }
    }
  }

  void _onPlaceSelected(
    LatLng selectedPlace,
    String name,
    String description,
    String imageUrl,
    double latitude,
    double longitude,
    String category1,
    String category2,
    String category3,
  ) {
    setState(() {
      _isPlaceSelected = true;
      _selectedPlaceName = name;
      _selectedPlaceDescription = description;
      _selectedPlaceImageUrl = imageUrl;
      _selectedPlaceLocation = LatLng(latitude, longitude);
      _selectedPlaceCategory1 = category1;
      _selectedPlaceCategory2 = category2;
      _selectedPlaceCategory3 = category3;
    });

    _goToLocation(_selectedPlaceLocation, zoom: 10);
    _getDirections(_userLocation, _selectedPlaceLocation); // Fetch route
  }

  Future<void> _getDirections(LatLng origin, LatLng destination) async {
    final String apiKey =
        "AIzaSyC4gULFHsrb14nNcNzQNwZa6tG0HNBIwmg"; // Replace with your API key
    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey";

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final String encodedPolyline =
          data['routes'][0]['overview_polyline']['points'];

      _addRoutePolyline(encodedPolyline);
    } else {
      print("Failed to fetch directions: ${response.body}");
    }
  }

  void _addRoutePolyline(String encodedPolyline) {
    // Use PolylinePoints to decode the encoded polyline string
    PolylinePoints polylinePoints = PolylinePoints();

    // Decode the polyline
    List<PointLatLng> decodedPoints =
        polylinePoints.decodePolyline(encodedPolyline);

    // Convert the decoded polyline points to LatLng objects
    List<LatLng> routePoints = decodedPoints
        .map((point) =>
            LatLng(point.latitude.toDouble(), point.longitude.toDouble()))
        .toList();

    setState(() {
      // Clear previous polylines
      _polylines.clear();

      // Add the new polyline to the map
      _polylines.add(
        Polyline(
          polylineId: PolylineId("route"),
          points: routePoints,
          color: Colors.blue,
          width: 5,
        ),
      );
    });
  }

  void _logout() async {
    await AuthProvider().logout(); // Calls your logout function
    Navigator.of(context).pushReplacementNamed(AppRoutes.auth);
    print("Logout tapped");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Travel Diary",
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: tealColor,
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white),
            onPressed: _logout, // Logout functionality.
          ),
        ],
      ),
      body: Container(
        color: eggShellColor, // Background color for better aesthetics.
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: "Search for a place...",
                  border: OutlineInputBorder(
                    borderSide: BorderSide(color: tealColor),
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: tealColor, width: 2.0),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(Icons.search, color: tealColor),
                    onPressed: _searchPlaces,
                  ),
                ),
              ),
            ),
            if (_places.isNotEmpty)
              Expanded(
                child: ListView.builder(
                  itemCount: _places.length,
                  itemBuilder: (context, index) {
                    var place = _places[index];
                    return Column(
                      children: [
                        ListTile(
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: Image.network(
                              place.imageUrl,
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                            ),
                          ),
                          title: Text(
                            place.name,
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onTap: () {
                            _onPlaceSelected(
                              LatLng(place.latitude, place.longitude),
                              place.name,
                              place.description,
                              place.imageUrl,
                              place.latitude,
                              place.longitude,
                              place.category1,
                              place.category2,
                              place.category3,
                            );
                            _places.clear(); // Clear the list after selection
                            _getDirections(_userLocation,
                                _selectedPlaceLocation); // Fetch route
                            setState(() {});
                          },
                        ),
                        Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Divider(
                            color: const Color.fromARGB(149, 1, 100,
                                100), // Customize the color to match the theme.
                            thickness: 1, // Adjust thickness if needed.
                            height: 1, // Space above and below the divider.
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    onMapCreated: (controller) {
                      if (!_controller.isCompleted) {
                        // Prevent multiple completions
                        _controller.complete(controller);
                      }
                      setState(() {
                        _isMapReady = true; // Set map readiness
                      });
                    },
                    initialCameraPosition: CameraPosition(
                      target: Location, // Replace with your LatLng
                      zoom: zoom,
                    ),
                    markers:
                        _markers, // Ensure _markers is properly initialized
                    myLocationEnabled: true, // Requires location permissions
                    polylines:
                        _polylines, // Ensure _polylines is properly initialized
                  ),
                  if (_isPlaceSelected)
                    PlaceDetailsBottomSheet(
                      height: _containerHeight,
                      placeName: _selectedPlaceName,
                      description: _selectedPlaceDescription,
                      imageUrl: _selectedPlaceImageUrl,
                      category1: _selectedPlaceCategory1,
                      category2: _selectedPlaceCategory2,
                      category3: _selectedPlaceCategory3,
                      onDragUpdate: (delta) {
                        setState(() {
                          _containerHeight -=
                              delta / MediaQuery.of(context).size.height;
                          _containerHeight = _containerHeight.clamp(
                              0.1, 0.5); // Keep in bounds
                        });
                      },
                      onDragEnd: (velocity) {
                        setState(() {
                          _containerHeight =
                              velocity < 0 ? 0.5 : 0.1; // Expand or collapse
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
