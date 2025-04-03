import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/Map_view/Layers/friends_layer.dart';
import 'package:serendip/features/Map_view/controller/map_controller.dart';
import 'package:serendip/features/Social_Media/find_friends/search_friends.dart';
import 'package:serendip/models/user_model.dart';
import '../../../core/utils/bottom_nav_bar.dart';
import '../../../core/utils/navigation_controller.dart';
import '../../Map_view/map_widget.dart';
import '../../location/location_provider.dart';
import '../../recomendation_system/widgets/search_bar.dart';

class FindFriendsPage extends StatefulWidget {
  @override
  _FindFriendsPageState createState() => _FindFriendsPageState();
}

class _FindFriendsPageState extends State<FindFriendsPage> {
  LatLng? currentUserLocation;
  List<UserModel> nearbyUsers = [];
  List<UserModel> searchResults = [];
  TextEditingController searchController = TextEditingController();
  UserRepository userRepository = UserRepository();
  static const String FRIENDS_LAYER = 'friends_layer';
  bool isSearching = false;
  bool hasSearched = false;

  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _initializeLayers();
    _getUserLocation();
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  void _onNavBarItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    NavigationController.navigateToScreen(context, index);
  }

  Future<void> _onSearchChanged() async {
    String query = searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        searchResults.clear();
        isSearching = false;
        hasSearched = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
      hasSearched = true;
    });

    final results = await userRepository.searchUsersByName(query);

    if (mounted) {
      setState(() {
        searchResults = results;
        isSearching = false;
      });
    }
  }

  void _initializeLayers() {
    final mapController = Provider.of<MapController>(context, listen: false);
    mapController.addLayer(FRIENDS_LAYER, FriendsLayer());
    mapController.toggleLayer(FRIENDS_LAYER, true);
  }

  Future<void> _getUserLocation() async {
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    LatLng? location = locationProvider.currentLocation;

    if (location != null) {
      setState(() {
        currentUserLocation = location;
      });
    }
  }

  Future<void> _findNearbyUsers() async {
    if (currentUserLocation != null) {
      List<UserModel> users = await userRepository.findNearbyUsers(currentUserLocation!, 5.0);
      _updateUsersOnMap(users);
    }
  }

  void _updateUsersOnMap(List<UserModel> users) {
    setState(() {
      nearbyUsers = users;
    });

 // Update the FriendsLayer markers
final mapController = Provider.of<MapController>(context, listen: false);
final friendsLayer = mapController.getLayer(FRIENDS_LAYER) as FriendsLayer?;
friendsLayer?.updateFriendLocations(context, nearbyUsers);


  }

  void _viewUserProfile(UserModel user) {
    Navigator.pushNamed(
      context,
      '/view_profile',
      arguments: user.userId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(title: const Text('Find Friends')),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: MapSearchBar(
                    searchController: searchController,
                    hintText: "Search for friends...",
                    onSearch: _onSearchChanged,
                    isQuery: false,
                  ),
                ),
              ),
              if (isSearching)
                const Center(child: CircularProgressIndicator())
              else if (hasSearched && searchResults.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final user = searchResults[index];
                      return ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.person)),
                        title: Text(user.username),
                        subtitle: const Text("Tap to view profile"),
                        onTap: () => _viewUserProfile(user),
                      );
                    },
                  ),
                ),
              Expanded(
                child: SharedMapWidget(
                  initialPosition: currentUserLocation ?? const LatLng(0, 0),
                  initialZoom: 12,
                ),
              ),
            ],
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

          Positioned(
            bottom: 120,
            right: 20,
            child: FloatingActionButton(
              child: const Icon(Icons.refresh),
              onPressed: _findNearbyUsers,
            ),
          ),
        ],
      ),
    );
  }
}
