import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:serendip/core/constant/colors.dart';
import 'package:serendip/features/Auth/auth_provider.dart';
import 'package:serendip/core/routes.dart';
import 'package:serendip/features/Map_view/controller/map_controller.dart';
import 'package:serendip/features/Map_view/layers/map_layer.dart';
import 'package:serendip/features/Map_view/map_widget.dart';
import 'package:serendip/features/Map_view/layers/places_layer.dart';
import 'package:serendip/features/Map_view/layers/trips_layer.dart';
import 'package:serendip/features/recomendation_system/widgets/search_bar.dart';
import 'package:serendip/features/Trip_Tracking/provider/trip_provider.dart';
import 'package:serendip/features/Trip_Tracking/trip_helper.dart';
import 'package:serendip/features/location/location_provider.dart';
import 'package:serendip/models/trip_model.dart';
import '../../models/places.dart';
import '../../services/api_service.dart';
import '../chat.dart/chat_provider.dart';
import '../chat.dart/contacts_screen.dart';
import '../profile.dart/presentation/view_profile.dart';
import '../recomendation_system/widgets/place_details_bottom_sheet.dart';
import '../recomendation_system/widgets/place_list.dart';
import '../../core/utils/bottom_nav_bar.dart';
import '../../core/utils/navigation_controller.dart';
import 'package:serendip/features/Auth/auth_provider.dart';

class MapScreen extends StatefulWidget {
  final TripModel? trip; // Accepts a Trip model directly

  const MapScreen({Key? key, this.trip}) : super(key: key);
  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final TextEditingController _searchController = TextEditingController();
  LatLng _userLocation = LatLng(0, 0);
  List<Place> _places = [];
  bool _isPlaceSelected = false;
  bool _isRecordingTrip = false;
  String _selectedPlaceName = '';
  String _selectedPlaceDescription = '';
  String _selectedPlaceImageUrl = '';
  String _selectedPlaceCategory1 = '';
  String _selectedPlaceCategory2 = '';
  String _selectedPlaceCategory3 = '';
  double _containerHeight = 0.5;
  bool _isLoading = false;
  static const String PLACES_LAYER = 'places_layer';
  static const String TRIPS_LAYER = 'trips_layer';
  int _selectedIndex = 0;

  // Trip filter value
  String _selectedTripFilter =
      "My Trips"; // Options: "My Trips", "Friends' Trips", "Collaborated Trips"

  @override
  void initState() {
    super.initState();
    _initializeLayers();
    _getUserLocation();
    Provider.of<ChatProvider>(context, listen: false).listenForUnreadMessages();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.trip != null) {
        _displayTrip(widget.trip!);
      }
    });
  }

  void _onNavBarItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    NavigationController.navigateToScreen(context, index);
  }

  void _initializeLayers() {
    final mapController = Provider.of<MapController>(context, listen: false);
    // Add PlacesLayer for place markers
    mapController.addLayer(PLACES_LAYER, PlacesLayer());
    mapController.toggleLayer(PLACES_LAYER, true);
    // Add TripsLayer for trip routes/markers
    mapController.addLayer(TRIPS_LAYER, TripsLayer() as MapLayer);
    mapController.toggleLayer(TRIPS_LAYER, true);
  }

  Future<void> _getUserLocation() async {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final mapController = Provider.of<MapController>(context, listen: false);
    setState(() {
      _userLocation = locationProvider.currentLocation ?? LatLng(0, 0);
    });
    mapController.moveCamera(_userLocation);
  }

  Future<void> _searchPlaces() async {
    String query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    final recommendations = await ApiService.fetchRecommendations(query);

    setState(() {
      _places = recommendations ?? [];
      _isPlaceSelected = false;
      _isLoading = false;
    });

    final mapController = Provider.of<MapController>(context, listen: false);
    mapController.clearLayer(PLACES_LAYER);
    final placesLayer = mapController.getLayer(PLACES_LAYER) as PlacesLayer?;
    if (placesLayer != null) {
      placesLayer.updatePlaces(_places);
    }
  }

  void _onPlaceSelected(Place place) async {
    setState(() {
      _isPlaceSelected = true;
      _selectedPlaceName = place.name;
      _selectedPlaceDescription = place.description;
      _selectedPlaceImageUrl = place.imageUrl;
      _selectedPlaceCategory1 = place.category1;
      _selectedPlaceCategory2 = place.category2;
      _selectedPlaceCategory3 = place.category3;
    });

    final mapController = Provider.of<MapController>(context, listen: false);
    final placesLayer = mapController.getLayer(PLACES_LAYER) as PlacesLayer?;
    if (placesLayer != null) {
      placesLayer.selectPlace(place);
      placesLayer.setUserLocation(_userLocation);
    }
    await Future.delayed(const Duration(milliseconds: 300));
    final success = await mapController.moveCamera(
      LatLng(place.latitude, place.longitude),
      zoom: 8,
    );
    if (!success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Could not move map to selected location. Please try again.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _displayTrip(TripModel trip) {
    print("Displaying trip: ${trip}");

    final mapController = Provider.of<MapController>(context, listen: false);
    final tripsLayer = mapController.getLayer('trips_layer') as TripsLayer?;

    if (tripsLayer == null) {
      print("TripsLayer not found.");
      return;
    }

    tripsLayer.clear();
    tripsLayer.addTripPolyline(trip.tripPath, trip.tripId);

    if (trip.tripPath.isNotEmpty) {
      mapController.moveCamera(trip.tripPath.first, zoom: 12);
    }

    setState(() {}); // Refresh UI
  }

  void _clearMap() {
    final mapController = Provider.of<MapController>(context, listen: false);
    mapController.clearAllLayers();
    setState(() {
      _isPlaceSelected = false;
      _places.clear();
    });
  }

  void _logout() async {
    await Provider.of<AuthProvider>(context, listen: false).logout();
    Navigator.of(context).pushReplacementNamed(AppRoutes.auth);
  }

  void _toggleTripRecording() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final mapController = Provider.of<MapController>(context, listen: false);
    final tripsLayer = mapController.getLayer('trips_layer') as TripsLayer?;

    if (tripsLayer == null) return;

    if (_isRecordingTrip) {
      await TripHelper.stopTrip(context);
      setState(() => _isRecordingTrip = false);
      tripsLayer.clear();
      tripProvider.removeListener(_updateActiveTripLayer); // ✅ Remove listener
    } else {
      bool tripStarted = await TripHelper.startTrip(context);
      if (tripStarted) {
        setState(() => _isRecordingTrip = true);
        tripProvider.addListener(_updateActiveTripLayer); // ✅ Add listener
        _updateActiveTripLayer();
      }
    }
  }

void _updateActiveTripLayer() {
  final tripProvider = Provider.of<TripProvider>(context, listen: false);
  final locationProvider = Provider.of<LocationProvider>(context, listen: false);
  final mapController = Provider.of<MapController>(context, listen: false);
  final tripsLayer = mapController.getLayer('trips_layer') as TripsLayer?;

  if (tripsLayer == null || tripProvider.currentTrip == null) return;

  final tripPath = tripProvider.currentTrip!.tripPath;
  final currentLocation = locationProvider.currentLocation;

  if (currentLocation == null) return;

  // Ensure the last recorded position is different from the current position
  if (tripPath.isEmpty || tripPath.last != currentLocation) {
    tripProvider.addLocation(currentLocation); // Add location to trip

    // Update polyline dynamically
    tripsLayer.updateTripPolyline(tripPath, "active_trip");

    // Move the animated circle (current position)
    tripsLayer.addRecordingTripEffect(currentLocation);

    // Move the camera to follow user
    mapController.moveCamera(currentLocation, zoom: 14);
  }
}

  Future<void> _fetchAndDisplayTrips() async {
    print("Fetching trips...");

    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      print("No user logged in. Cannot fetch trips.");
      return;
    }

    print(
        "Fetching trips for user ID: $userId with filter: $_selectedTripFilter");

    await tripProvider.fetchTrips(userId: userId, filter: _selectedTripFilter);

    print("Trips fetched: ${tripProvider.trips.length}");

    _updateTripsLayer();
  }

  /// Update the TripsLayer with fetched trips.
  void _updateTripsLayer() {
    print("Updating TripsLayer...");

    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final mapController = Provider.of<MapController>(context, listen: false);
    final tripsLayer = mapController.getLayer(TRIPS_LAYER) as TripsLayer?;

    if (tripsLayer == null) {
      print("TripsLayer not found.");
      return;
    }

    tripsLayer.clear();
    print("Cleared previous trip data.");

    for (var trip in tripProvider.trips) {
      if (trip.tripPath.isNotEmpty) {
        print("Adding trip: ${trip.tripId}, Points: ${trip.tripPath.length}");
      } else {
        print("Skipping trip ${trip.tripId} (empty path)");
      }
      tripsLayer.addTripPolyline(trip.tripPath, trip.tripId);
    }

    print("Active polylines: ${tripsLayer.getPolylines().length}");
    print("Active markers: ${tripsLayer.getMarkers().length}");

    setState(() {}); // Refresh UI
  }

  Future<void> _loadTripById(String tripId) async {
    print("Loading trip with ID: $tripId");

    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final mapController = Provider.of<MapController>(context, listen: false);
    final tripsLayer = mapController.getLayer(TRIPS_LAYER) as TripsLayer?;

    if (tripsLayer == null) {
      print("TripsLayer not found.");
      return;
    }

    // Fetch the specific trip
    final trip = await tripProvider.fetchTripById(tripId);
    if (trip == null) {
      print("Trip not found.");
      return;
    }

    tripsLayer.clear(); // Clear previous trips
    tripsLayer.addTripPolyline(
        trip.tripPath, trip.tripId); // Display only this trip

    print("Trip displayed on map: ${trip.tripId}");

    if (trip.tripPath.isNotEmpty) {
      mapController.moveCamera(trip.tripPath.first,
          zoom: 12); // Center on first point
    }

    setState(() {}); // Refresh UI
  }

  /// Show trip filter options via bottom sheet.
  void _showTripFilters() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateSheet) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Filter Trips",
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildFilterOption("My Trips", setStateSheet),
                    _buildFilterOption("Friends' Trips", setStateSheet),
                    _buildFilterOption("Collaborated Trips", setStateSheet),
                  ],
                ),
                const SizedBox(height: 10),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(context).pop();
                    // Fetch and update trips based on the selected filter
                    await _fetchAndDisplayTrips();
                  },
                  child: const Text("Apply Filter"),
                ),
              ],
            ),
          );
        });
      },
    );
  }

  /// Build individual filter option button.
  Widget _buildFilterOption(
      String option, void Function(void Function()) setStateSheet) {
    bool isSelected = _selectedTripFilter == option;
    return OutlinedButton(
      onPressed: () {
        setStateSheet(() {
          _selectedTripFilter = option;
        });
      },
      style: OutlinedButton.styleFrom(
        backgroundColor: isSelected ? Colors.greenAccent : Colors.white,
      ),
      child: Text(option,
          style: TextStyle(color: isSelected ? Colors.white : Colors.black)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: eggShellColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Serendip", style: TextStyle(color: Colors.white)),
        backgroundColor: tealColor,
        automaticallyImplyLeading: false,
       actions: [
  Consumer<ChatProvider>(
    builder: (context, chatProvider, child) {
      int totalUnread = chatProvider.unreadCounts.values.fold(0, (a, b) => a + b);

      return Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.chat_rounded, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => ContactsScreen()),
              );
            },
          ),
          if (totalUnread > 0) // Show badge only if there are unread messages
            Positioned(
              right: 6,
              top: 6,
              child: CircleAvatar(
                radius: 10,
                backgroundColor: Colors.red,
                child: Text(
                  totalUnread.toString(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
        ],
      );
    },
  ),
  IconButton(
    icon: const Icon(Icons.logout, color: Colors.white),
    onPressed: _logout,
  ),
],

      ),
      body: Stack(
        children: [
          Column(
            children: [
              MapSearchBar(
                searchController: _searchController,
                onSearch: _searchPlaces,
                hintText: 'Let us find places for you..',
                isQuery: true,
              ),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.all(10.0),
                  child: Center(
                    child: CircularProgressIndicator(color: tealColor),
                  ),
                ),
              if (!_isLoading && _places.isNotEmpty)
                Expanded(
                  child: PlaceList(
                    userLocation: _userLocation,
                    places: _places,
                    onPlaceSelected: _onPlaceSelected,
                  ),
                ),
              Expanded(
                child: SharedMapWidget(
                  initialPosition: _userLocation,
                  initialZoom: 12,
                ),
              ),
            ],
          ),
          // Floating button for starting/stopping trips.
          Positioned(
            bottom: 90,
            right: 10,
            child: FloatingActionButton(
              heroTag: 'fab_1',
              onPressed: _toggleTripRecording,
              backgroundColor: _isRecordingTrip ? Colors.red : Colors.green,
              child: Icon(_isRecordingTrip ? Icons.stop : Icons.play_arrow,
                  color: Colors.white),
              tooltip: _isRecordingTrip ? 'Stop Trip' : 'Start Trip',
            ),
          ),
          // Floating button for clearing map.
          Positioned(
            top: 150,
            right: 10,
            child: FloatingActionButton.small(
              heroTag: 'fab_2',
              onPressed: _clearMap,
              backgroundColor: tealColor,
              child: const Icon(Icons.refresh, color: Colors.white, size: 20),
              tooltip: 'Clear map',
            ),
          ),
          // Floating button for trip filter options.
          Positioned(
            bottom: 150,
            right: 10,
            child: FloatingActionButton(
              heroTag: 'fab_3',
              onPressed: _showTripFilters,
              backgroundColor: Colors.orange,
              child: const Icon(Icons.filter_list, color: Colors.white),
              tooltip: 'Filter Trips',
            ),
          ),
          // Bottom navigation bar.
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: CustomBottomNavBar(
              selectedIndex: _selectedIndex,
              onItemSelected: _onNavBarItemSelected,
            ),
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
                  _containerHeight = _containerHeight.clamp(0.1, 0.5);
                });
              },
              onDragEnd: (velocity) {
                setState(() {
                  _containerHeight = velocity < 0 ? 0.5 : 0.15;
                });
              },
              onClose: () {
                setState(() {
                  _isPlaceSelected = false;
                });
              },
            ),
        ],
      ),
    );
  }
}
