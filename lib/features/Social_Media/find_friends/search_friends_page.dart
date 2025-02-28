import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/Map_view/Layers/map_layer.dart';
import 'package:serendip/features/Map_view/controller/map_controller.dart';
import 'package:serendip/features/Map_view/layers/friends_layer.dart';
import 'package:serendip/features/Social_Media/find_friends/search_friends.dart';
import 'package:serendip/models/user_model.dart';
import 'package:serendip/services/location_service.dart';
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
  List<UserModel> searchResults = []; // New list for search results
  TextEditingController searchController = TextEditingController();
  UserRepository userRepository = UserRepository();
  static const String FRIENDS_LAYER = 'friends_layer';
  bool isSearching = false; // Track if user is searching

  int _selectedIndex = 1;

  @override
  void initState() {
    super.initState();
    _initializeLayers();
    _getUserLocation();
    
    // Add listener to search controller
    searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    searchController.removeListener(_onSearchChanged);
    searchController.dispose();
    super.dispose();
  }

  // Debounce search to avoid too many API calls
  Future<void> _onSearchChanged() async {
    if (searchController.text.isEmpty) {
      setState(() {
        searchResults = [];
        isSearching = false;
      });
      return;
    }

    setState(() {
      isSearching = true;
    });

    // Perform the search
    final results = await userRepository.searchUsersByName(searchController.text.trim());
    
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
  final mapController = Provider.of<MapController>(context, listen: false);

  LatLng? location = locationProvider.currentLocation;

  if (location != null) {
    setState(() {
      currentUserLocation = location;
    });

    mapController.moveCamera(currentUserLocation!);
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

    final mapController = Provider.of<MapController>(context, listen: false);
    final friendsLayer = mapController.getLayer(FRIENDS_LAYER) as FriendsLayer?;
    if (friendsLayer != null) {
      friendsLayer.updateFriends(users);
    }
  }

  void _onNavBarItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    NavigationController.navigateToScreen(context, index);
  }

  void _viewUserProfile(UserModel user) {
    // Navigate to user profile view
    Navigator.pushNamed(
      context,
      '/view_profile',
      arguments: user.userId,
    );
  }

  Widget _buildUserList() {
    if (searchResults.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const ClampingScrollPhysics(),
        itemCount: searchResults.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final user = searchResults[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundImage: user.profileImage!= null
                  ? NetworkImage(user.profileImage!)
                  : const AssetImage('assets/images/profile.png') as ImageProvider,
            ),
            title: Text(user.username),
            subtitle: Text(user.email),
            onTap: () => _viewUserProfile(user),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Find Friends'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: MapSearchBar(
                  searchController: searchController,
                  onSearch: () {}, // Search is now handled by listener
                  hintText: "Search for friends...",
                  isQuery: false,
                ),
              ),
              if (isSearching)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: CircularProgressIndicator()),
                ),
              _buildUserList(),
              Expanded(
                child: currentUserLocation == null
                    ? const Center(child: CircularProgressIndicator())
                    : SharedMapWidget(
                        initialPosition: currentUserLocation!,
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.refresh),
        onPressed: _findNearbyUsers,
      ),
    );
  }
}
