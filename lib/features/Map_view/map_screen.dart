import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:serendip/core/constant/colors.dart';
import 'package:serendip/features/Auth/auth_provider.dart';
import 'package:serendip/core/routes.dart';
import 'package:serendip/features/Map_view/Layers/map_layer.dart';
import 'package:serendip/features/Map_view/controller/map_controller.dart';
import 'package:serendip/features/Map_view/map_widget.dart';
import 'package:serendip/features/Map_view/Layers/places_layer.dart';
import 'package:serendip/features/Map_view/Layers/trips_layer.dart';
import 'package:serendip/features/recomendation_system/widgets/search_bar.dart';
import 'package:serendip/features/Trip_Tracking/provider/trip_provider.dart';
import 'package:serendip/features/Trip_Tracking/trip_helper.dart';
import 'package:serendip/features/location/location_provider.dart';
import 'package:serendip/models/ads_model.dart';
import 'package:serendip/models/trip_model.dart';
import '../../models/places.dart';
import '../../services/api_service.dart';
import '../Reviews/review_provider.dart';
import '../Social_Media/friend_request/friend_request_provider.dart';
import '../Social_Media/friend_request/friend_request_screen.dart';
import '../chat/chat_provider.dart';
import '../chat/contacts_screen.dart';
import '../profile.dart/provider/profile_provider.dart';
import '../recomendation_system/widgets/place_details_bottom_sheet.dart';
import '../recomendation_system/widgets/place_list.dart';
import '../../core/utils/bottom_nav_bar.dart';
import '../../core/utils/navigation_controller.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import 'Layers/ad_layer.dart';

class MapScreen extends StatefulWidget {
  final TripModel? trip;
  final BusinessAd? ad;

const MapScreen({Key? key, this.trip, this.ad}) : super(key: key);

  @override
  _MapScreenState createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  LatLng _userLocation = const LatLng(0, 0);
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
  static const String REVIEWS_LAYER = 'reviews_layer';
    static const String FRIENDS_LAYER = 'friends_layer';
  int _selectedIndex = 0;
  String _selectedTripFilter = "My Trips";
 bool _isCameraIconVisible = false;
 static const String ADS_LAYER = 'ads_layer';
 bool _isCollaborationActive = false;
late StreamSubscription _collaborativeTripSub;

@override
void initState() {
  super.initState();
  WidgetsBinding.instance.addObserver(this);
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    _initializeLayers();
    _checkActiveTrip();
 WidgetsBinding.instance.addPostFrameCallback((_) {
    _listenToCollaborativeTrips();
  });

   final tripProvider = Provider.of<TripProvider>(context, listen: false);
await tripProvider.checkAndSetActiveCollaborativeTrip();
if(widget.ad != null){
      _setupAdRoute();
      }
   
  });
  _getUserLocation();
  Provider.of<ChatProvider>(context, listen: false).listenForUnreadMessages();

  if (widget.trip != null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      print("Displaying Trip ${widget.trip}");
      _displayTrip(widget.trip!);
    });
  }



  
}



void _listenToCollaborativeTrips() {
  final userId = Provider.of<ProfileProvider>(context, listen: false).currentUserId;
  final mapController = Provider.of<MapController>(context, listen: false);

  print("Listening for collaborative trips for user: $userId");

  _collaborativeTripSub = FirebaseFirestore.instance
    .collection('trips')
    .where('collaborators', arrayContains: userId)
    .where('isActive', isEqualTo: true)
    .snapshots()
    .listen((snapshot) {
      if (snapshot.docs.isNotEmpty) {
        print("Collaborative trip found! Document count: ${snapshot.docs.length}");

        final tripData = snapshot.docs.first.data();
        print("Collaborative trip data: ${tripData}");
        _isCollaborationActive = true;
setState(() {
  
        print("Collab ${_isCollaborationActive}");
  
});

        _displayCollaborativeTrip(tripData);
     

        if (mounted) {
          print("Displaying snackbar alert for collaborative trip.");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('A collaborator started a trip that includes you!'),
              duration: Duration(seconds: 4),
            ),
          );
        }
      } else {
        print("No collaborative trips found for user $userId.");
          setState(() {
            // mapController.tripsLayer.clear();
             });
   
           setState((){
         _isCollaborationActive = false;
         _isRecordingTrip = false;
       

           });
            print('remove UI');
          
         
     
      }
    });
}




void _setupAdRoute() async {

  print('map screen setting ad ${widget.ad!}');

  final mapController = Provider.of<MapController>(context, listen: false);
  final adLayer = mapController.getLayer(ADS_LAYER) as AdLayer;
  
  // Set user's current location
  adLayer.setUserLocation(_userLocation);

  // Tell AdLayer about the ad
  await adLayer.setAds([
    BusinessAd(
      id: 'target-ad',
      location: GeoPoint(
        widget.ad!.location.latitude,
        widget.ad!.location.longitude,
      ),
      imageUrl: '', // <-- Empty imageUrl = no image = bouncing default marker
      title: widget.ad!.title,
      description: widget.ad!.description,
    ),
  ]);

  // Move camera to show both user and ad location
  final bounds = LatLngBounds(
    southwest: LatLng(
      min(_userLocation.latitude, widget.ad!.location.latitude),
      min(_userLocation.longitude, widget.ad!.location.longitude),
    ),
    northeast: LatLng(
      max(_userLocation.latitude, widget.ad!.location.latitude),
      max(_userLocation.longitude, widget.ad!.location.longitude),
    ),
  );

  mapController.controller?.animateCamera(

    CameraUpdate.newLatLngBounds(bounds, 100),
    
  );
      print('animating Camera');
}

// void _initializeLayers() {
//   final mapController = Provider.of<MapController>(context, listen: false);
//   mapController.addLayer(PLACES_LAYER, PlacesLayer());
//   mapController.addLayer(TRIPS_LAYER, TripsLayer());
//   mapController.addLayer(ADS_LAYER, AdLayer());
  
//   mapController.toggleLayer(PLACES_LAYER, true);
//   mapController.toggleLayer(TRIPS_LAYER, true);
//   mapController.toggleLayer(ADS_LAYER, true);
// }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
     _collaborativeTripSub.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkActiveTrip();
    }
  }


  Widget _styledFab({
  required IconData icon,
  required String tooltip,
  required VoidCallback onPressed,
  required String heroTag,
}) {
  return FloatingActionButton.small(
    heroTag: heroTag,
    onPressed: onPressed,
    backgroundColor: tealColor,
    tooltip: tooltip,
    // shape: RoundedRectangleBorder(
    //   borderRadius: BorderRadius.circular(16),
    //   side: BorderSide(color: tealColor, width: 2),
    // ),
    child: Icon(icon, color: Colors.white,size: 20,),
  );
}


  Future<void> _checkActiveTrip() async {
  final tripProvider = Provider.of<TripProvider>(context, listen: false);
  final mapController = Provider.of<MapController>(context, listen: false);
  final locationProvider = Provider.of<LocationProvider>(context, listen: false);

  setState(() {
    _isRecordingTrip = tripProvider.isRecording;
  });

  // Check if there's an active personal trip
  if (_isRecordingTrip && tripProvider.currentTrip != null) {
    if (locationProvider.currentLocation != null) {
      // Add the polyline for the active personal trip
      mapController.addTripPolyline(
          tripProvider.currentTrip!.tripPath, "active_trip");
      // Add the circle for the user's current location
      mapController.addActiveTripCircle(locationProvider.currentLocation!);
    }

    // Show the active personal trip notification
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Trip recording is active'),
        duration: Duration(seconds: 3),
      ));
    }
  } else {
    // Check if there is an active collaborative trip
    final collaborativeTrip = await _checkForCollaborativeTrip();

    if (collaborativeTrip != null) {
      // Display the collaborative trip as if it’s the user's active trip
      _displayCollaborativeTrip(collaborativeTrip);

      // Show notification for the collaborative trip
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('You have an active trip in collaboration with others!'),
          duration: Duration(seconds: 3),
          // action: SnackBarAction(
          //   label: 'View Trip',
          //   onPressed: _viewCollaborativeTrip,
          // ),
        ));
      }
    }
  }
}

Future<Map<String, dynamic>?> _checkForCollaborativeTrip() async {
  // Query Firestore for active collaborative trips involving this user
  final userId = Provider.of<ProfileProvider>(context, listen: false).currentUserId;
  final tripSnapshot = await FirebaseFirestore.instance
      .collection('trips')
      .where('collaborators', arrayContains: userId)
      .where('isActive', isEqualTo: true)
      .limit(1)  // Assuming only one active collaborative trip
      .get();

  if (tripSnapshot.docs.isNotEmpty) {
    return tripSnapshot.docs.first.data();
  }
  return null;
}

void _displayCollaborativeTrip(Map<String, dynamic> collaborativeTrip) {
  print("Displaying collaborative trip");

  final mapController = Provider.of<MapController>(context, listen: false);
  final tripProvider = Provider.of<TripProvider>(context, listen: false);

  try {
    final geoJson = collaborativeTrip['trip_path'] as Map<String, dynamic>?;
    if (geoJson == null || geoJson['coordinates'] == null) {
      print("Invalid trip path");
      return;
    }

    final currentTripId = tripProvider.currentTrip?.tripId;
    if (currentTripId == null) {
      print("No current trip ID");
      return;
    }

    mapController.tripsLayer.listenForTripImages(currentTripId, context);

    final coordinates = geoJson['coordinates'] as List;
    final List<LatLng> path = coordinates.map((point) {
      if (point is List && point.length == 2) {
        final lon = point[0];
        final lat = point[1];
        return LatLng(lat, lon);
      }
      return LatLng(0, 0);
    }).toList();

    if (path.isEmpty) {
      print("Trip path is empty");
      return;
    }

    final LatLng cameraTarget = path.first;
    final LatLng lastLocation = path.last;

  print("''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''");
    print(cameraTarget);



    mapController.addTripPolyline(path, "collaborative_trip");
    mapController.addActiveTripCircle(lastLocation);

mapController.moveCamera(
          cameraTarget,
          zoom: 16,
          tilt: 60, // 3D effect for trip view
          bearing: 30, // Slight angle for a dynamic view
        );;


    print("Collaborative trip displayed");
  } catch (e) {
    print("Error displaying collaborative trip: $e");
  }
}

// void _viewCollaborativeTrip() {
//   // Handle what happens when the user clicks on "View Trip"
//   // You can navigate to the trip screen or display detailed information
//   Navigator.push(
//     context,
//     MaterialPageRoute(
//       builder: (context) => TripDetailScreen(
//         tripId: 'collaborative_trip_id',  // You can pass the trip ID here
//       ),
//     ),
//   );
// }

  void _onNavBarItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    NavigationController.navigateToScreen(context, index);
  }

void _initializeLayers() {
  final mapController = Provider.of<MapController>(context, listen: false);
  
  // Places Layer
  mapController.addLayer(PLACES_LAYER, PlacesLayer());
  mapController.toggleLayer(PLACES_LAYER, true);
  
  // Trips Layer
  mapController.addLayer(TRIPS_LAYER, TripsLayer());
  mapController.toggleLayer(TRIPS_LAYER, true);
  
  // Reviews Layer
  // mapController.addLayer(REVIEWS_LAYER, ReviewsLayer());
  mapController.toggleLayer(REVIEWS_LAYER, true);
  
  // Friends Layer
  // mapController.addLayer(FRIENDS_LAYER, FriendsLayer());
  mapController.toggleLayer(FRIENDS_LAYER, false);
  
  // Ads Layer
  // mapController.addLayer(ADS_LAYER, AdLayer());
  mapController.toggleLayer(ADS_LAYER, true);
}


  Future<void> _getUserLocation() async {
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);
    final mapController = Provider.of<MapController>(context, listen: false);
    setState(() {
      _userLocation = locationProvider.currentLocation ?? const LatLng(0, 0);
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
      zoom: 15,
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

 void _displayTrip(TripModel trip) async {
  print('--- Displaying Trip: ${trip.tripId} ---');

  final mapController = Provider.of<MapController>(context, listen: false);
  final tripsLayer = mapController.getLayer(TRIPS_LAYER) as TripsLayer?;

  if (tripsLayer == null) {
    print('TripsLayer is null!');
    return;
  }

  print('Clearing existing trips...');
  tripsLayer.clear();

  print('Adding trip polyline with ${trip.tripPath.length} points...');
  tripsLayer.addTripPolyline(trip.tripPath, trip.tripId);

  final tripProvider = Provider.of<TripProvider>(context, listen: false);
  print('Fetching images for trip: ${trip.tripId}');
  final images = await tripProvider.fetchTripImages(trip.tripId);
  print('Fetched ${images.length} images.');


if(images.isNotEmpty){ 
  for (var image in images) {
    LatLng location = LatLng(image['latitude'], image['longitude']);
    print('Adding image marker at ${location.latitude}, ${location.longitude}');
    tripsLayer.addImageMarker(context, location, image['image_url']);
  }
  }

  if (trip.tripPath.isNotEmpty) {
    print('Moving camera to start of trip: ${trip.tripPath.first}');
    mapController.moveCamera(trip.tripPath.first, zoom: 12);
  } else {
    print('Trip path is empty.');
  }

  setState(() {
    print('State updated.');
  });

  print('--- Trip Display Complete ---');
}


  void _clearMap() {
    final mapController = Provider.of<MapController>(context, listen: false);
    mapController.clearLayer(PLACES_LAYER);
    mapController.clearLayer(TRIPS_LAYER);
   
    setState(() {
      _isPlaceSelected = false;
      _places.clear();
    });
  }

  void _toggleTripRecording() async {
    final mapController = Provider.of<MapController>(context, listen: false);
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: false);

    if (_isRecordingTrip) {
      await TripHelper.stopTrip(context);
      setState(() => _isRecordingTrip = false);

      // Smoothly reset camera when trip stops
      mapController.moveCamera(
        locationProvider.currentLocation ?? _userLocation,
        zoom: 14,
        tilt: 0,
        bearing: 0,
      );
    } else {
      bool tripStarted = await TripHelper.startTrip(context);

      if (tripStarted) {
        setState(() => _isRecordingTrip = true);

        // Smoothly move camera to user’s location with immersive effect
        mapController.moveCamera(
          locationProvider.currentLocation ?? _userLocation,
          zoom: 16,
          tilt: 60, // 3D effect for trip view
          bearing: 30, // Slight angle for a dynamic view
        );
      }
    }
  }

  Future<void> _captureAndUploadImage(BuildContext context) async {
    // if (!_isRecordingTrip) {
    //   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
    //       content: Text('Please start a trip before capturing images')));
    //   return;
    // }

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile =
          await picker.pickImage(source: ImageSource.camera);

      if (pickedFile == null) return;

      File imageFile = File(pickedFile.path);
      final tripProvider = Provider.of<TripProvider>(context, listen: false);

      if (tripProvider.isUploading) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Please wait for the previous upload to complete')));
        return;
      }

      await tripProvider.captureImage(imageFile, context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error capturing image: ${e.toString()}')));
      }
    }
  }



  Future<void> _fetchAndDisplayTrips() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) return;

    await tripProvider.fetchTrips(userId: userId, filter: _selectedTripFilter);
    _updateTripsLayer();
  }

  void _updateTripsLayer() async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final mapController = Provider.of<MapController>(context, listen: false);
    final tripsLayer = mapController.getLayer(TRIPS_LAYER) as TripsLayer?;

    if (tripsLayer == null) return;

    tripsLayer.clear();

    for (var trip in tripProvider.trips) {
      if (trip.tripPath.isNotEmpty) {
        tripsLayer.addTripPolyline(trip.tripPath, trip.tripId);
      }

      final images = await tripProvider.fetchTripImages(trip.tripId);
      for (var image in images) {
        LatLng location = LatLng(image['latitude'], image['longitude']);
        tripsLayer.addImageMarker(context, location, image['image_url']);
      }
    }

    setState(() {});
  }

  void _showTripFilters() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        // local variable inside the builder
        List<String> selectedFilters = [];

        return StatefulBuilder(
          builder: (context, setStateSheet) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 16,
                right: 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    "Select Trip Filters",
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Filter Cards
                  _buildFilterCard(
                      "My Trips", Icons.person, selectedFilters, setStateSheet),
                  const SizedBox(height: 12),
                  _buildFilterCard("Friends' Trips", Icons.group,
                      selectedFilters, setStateSheet),
                  const SizedBox(height: 12),
                  _buildFilterCard("Collaborated Trips", Icons.people_alt,
                      selectedFilters, setStateSheet),

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();
                        // You can pass selectedFilters somewhere if needed
                        await _fetchAndDisplayTrips();
                      },
                      icon: const Icon(Icons.check),
                      label: const Text("Apply Filters"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterCard(
    String title,
    IconData icon,
    List<String> selectedFilters,
    void Function(void Function()) setStateSheet,
  ) {
    final isSelected = selectedFilters.contains(title);

    return InkWell(
      onTap: () {
        setStateSheet(() {
          if (isSelected) {
            selectedFilters.remove(title);
          } else {
            selectedFilters.add(title);
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              isSelected ? tealColor.withOpacity(0.01) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? tealColor : Colors.grey.shade300,
            width: 1.5,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: tealColor.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? tealColor : Colors.grey),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  color: isSelected ? tealColor : Colors.black87,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: isSelected ? tealColor : Colors.grey,
            )
          ],
        ),
      ),
    );
  }

  void _handleLongPress(LatLng position, BuildContext context) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );

      String placeName = "Unknown Place";

      if (placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        placeName = (place.subLocality != null && place.subLocality!.isNotEmpty)
            ? place.subLocality!
            : (place.locality != null && place.locality!.isNotEmpty)
                ? place.locality!
                : "Unknown Place";

        print(";-----------------------------------");
        print("Name: ${place.name}");
        print("Admin Area: ${place.administrativeArea}");
        print("Locality: ${place.locality}");
        print("Street: ${place.street}");
        print("SubLocality: ${place.subLocality}");
        print("Thoroughfare: ${place.thoroughfare}");
        print("SubThoroughfare: ${place.subThoroughfare}");
      }

      _showAddReviewDialog(context, position, placeName);
    } catch (e) {
      print("❌ Error during reverse geocoding: $e");
      _showAddReviewDialog(context, position, "Unknown Place");
    }
  }

void _showAddReviewDialog(
      BuildContext context, LatLng position, String placeName) {
    final TextEditingController reviewController = TextEditingController();
    final reviewProvider = Provider.of<ReviewProvider>(context, listen: false);
    double selectedRating = 0.0;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            "Add Review",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Rate the area",
              ),
              SizedBox(height: 8),
              RatingBar.builder(
                initialRating: selectedRating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: true,
                itemCount: 5,
                unratedColor: Colors.grey.shade300,
                itemPadding: EdgeInsets.symmetric(horizontal: 2.0),
                itemBuilder: (context, _) => Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                ),
                onRatingUpdate: (rating) {
                  selectedRating = rating;
                },
              ),
              SizedBox(height: 20),
              TextField(
                controller: reviewController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: "Write your review here...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
            ],
          ),
          actions: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tealColor,
                      side: BorderSide(color: tealColor),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text("Cancel"),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                SizedBox(width: 12), // spacing between buttons
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.white,
                      backgroundColor: tealColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text("Submit"),
                    onPressed: () async {
                      if (reviewController.text.trim().isNotEmpty) {
                        String reviewId =
                            '${position.latitude},${position.longitude}';
                            print('adding review');
                                FocusScope.of(context).unfocus();
                        await reviewProvider.addReview(
                          reviewId,
                          placeName,
                          reviewController.text.trim(),
                          selectedRating,
                          context,
                        );
                        print('Review loaded');
                        Navigator.pop(context);
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }



  @override
  Widget build(BuildContext context) {
    final reviewProvider = Provider.of<ReviewProvider>(context);
    return Scaffold(
      backgroundColor: eggShellColor,
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text("Serendip", style: TextStyle(color: Colors.white)),
        backgroundColor: tealColor,
        automaticallyImplyLeading: false,
        actions: [
          Consumer<FriendRequestProvider>(
            builder: (context, friendRequestProvider, child) {
              int unreadRequests = friendRequestProvider.pendingRequests.length;
              return Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications, color: Colors.white),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => FriendRequestPage()),
                      );
                    },
                  ),
                  if (unreadRequests > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          unreadRequests.toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              int totalUnread =
                  chatProvider.unreadCounts.values.fold(0, (a, b) => a + b);
              return Stack(
                children: [
                  IconButton(
                    icon: Image.asset(
                      'assets/images/chat_icon.png',
                      width: 24,
                      height: 24,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => ContactsScreen()),
                      );
                    },
                  ),
                  if (totalUnread > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: CircleAvatar(
                        radius: 10,
                        backgroundColor: Colors.red,
                        child: Text(
                          totalUnread.toString(),
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 10),
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
                  onLongPress: (LatLng position) =>
                      _handleLongPress(position, context),
                  initialPosition: _userLocation,
                  initialZoom: 12,
                ),
              ),
            ],
          ),
          if (_isRecordingTrip)
            Positioned(
              top: 100,
              left: 20,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record,
                        color: Colors.white, size: 12),
                    SizedBox(width: 8),
                    Text(
                      'Recording Trip',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        Positioned(
  bottom: 120,
  right: 10,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      if ( _isRecordingTrip || _isCollaborationActive)
      _styledFab(
        icon: Icons.camera_alt,
        tooltip: 'Capture Image',
        onPressed: () => _captureAndUploadImage(context),
        heroTag: 'fab_4',
      ),
      const SizedBox(height: 6),
      _styledFab(
        icon: _isRecordingTrip || _isCollaborationActive ? Icons.stop : Icons.play_arrow,
        tooltip: _isRecordingTrip || _isCollaborationActive ? 'Stop Trip' : 'Start Trip',
        onPressed: _toggleTripRecording,
        heroTag: 'fab_1',
      ),
      const SizedBox(height: 6),
      _styledFab(
        icon: Icons.filter_list,
        tooltip: 'Filter Trips',
        onPressed: _showTripFilters,
        heroTag: 'fab_3',
      ),
    ],
  ),
),

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
