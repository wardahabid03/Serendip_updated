import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/profile.dart/presentation/widgets/trip_card.dart';
import '../../../core/routes.dart';
import '../../../core/utils/bottom_nav_bar.dart';
import '../../../core/utils/navigation_controller.dart';
import '../../../models/friend_request_model.dart';
import '../../../models/trip_model.dart';
import '../../Social_Media/friend_request/friend_request_provider.dart';
import '../../Trip_Tracking/provider/trip_provider.dart';
import '../provider/profile_provider.dart';
import '../../../core/constant/colors.dart';
import 'widgets/photo_grid.dart';

class ViewProfileScreen extends StatefulWidget {
  final String? userId; // If null, shows current user's profile

  const ViewProfileScreen({
    Key? key,
    this.userId,
  }) : super(key: key);

  @override
  State<ViewProfileScreen> createState() => _ViewProfileScreenState();
}

class _ViewProfileScreenState extends State<ViewProfileScreen> {
  late Future<Map<String, dynamic>> _profileFuture;
  int _selectedIndex = 3;
  bool _isCurrentUser = false;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  void _loadProfile() {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    // Check if we're viewing our own profile
    _isCurrentUser =
        widget.userId == 'userId' || widget.userId == _currentUserId;

        print('user id ${widget.userId}');

    // Load appropriate profile data
    _profileFuture = _isCurrentUser
        ? profileProvider.fetchUserProfile()
        : profileProvider.fetchUserProfile(userId: widget.userId!);
  }




  void _onNavBarItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    NavigationController.navigateToScreen(context, index);
  }



  Future<void> _refreshProfile() async {
    setState(() {
      _loadProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        automaticallyImplyLeading:
            !_isCurrentUser, // Show back button for other profiles
        actions: [
          if (_isCurrentUser) ...[
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () => Navigator.pushNamed(context, '/settingsscreen')
                  .then((_) => _refreshProfile()),
            ),
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => Navigator.pushNamed(context, '/edit_profile')
                  .then((_) => _refreshProfile()),
            ),
          ],
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshProfile,
        child: FutureBuilder<Map<String, dynamic>>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline,
                        size: 48, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading profile: ${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _refreshProfile,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_off, size: 48, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Profile not found',
                      style: TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              );
            }

            final profile = snapshot.data!;
            final isPublic = profile['isPublic'] ?? false;
            final isFriend = profile['areFriends'] ?? false;

            // Show limited profile for private accounts
            if (!_isCurrentUser && !isPublic && !isFriend) {
              return _buildPrivateProfile(profile);
            }

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildProfileHeader(profile, context),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatsSection(profile),
                        const SizedBox(height: 24),
                        if (profile['bio'] != null &&
                            profile['bio'].isNotEmpty) ...[
                          const Text(
                            'About',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            profile['bio'],
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                        _buildTripsSection(profile),
                        const SizedBox(height: 24),
                        _buildPhotosSection(profile),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: _isCurrentUser
          ? CustomBottomNavBar(
              selectedIndex: _selectedIndex,
              onItemSelected: _onNavBarItemSelected,
            )
          : null,
    );
  }

  Widget _buildPrivateProfile(Map<String, dynamic> profile) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
           const SizedBox(height:20),
          CircleAvatar(
            radius: 60,
            backgroundImage: profile['profileImage'] != null &&
                    profile['profileImage'].isNotEmpty
                ? NetworkImage(profile['profileImage'])
                : const AssetImage('assets/images/profile.png')
                    as ImageProvider,
          ),
          const SizedBox(height: 16),
          Text(
            profile['username'] ?? 'User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'This account is private',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          if (!profile['areFriends']) _buildFriendRequestButton(profile),
        ],
      ),
    );
  }

  Widget _buildFriendRequestButton(Map<String, dynamic> profile) {
    return FutureBuilder<String>(
      future: Provider.of<FriendRequestProvider>(context, listen: false)
          .getFriendRequestStatus(widget.userId!), // Fetch request status
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator(); // Show loading indicator
        }

        String status = snapshot.data!; // Friend request status

        return ElevatedButton(
          onPressed: status == 'friends'
              ? null // Disable button if already friends
              : () async {
                  try {
                    var provider = Provider.of<FriendRequestProvider>(context,
                        listen: false);
                    if (status == 'none') {
                      await provider.sendFriendRequest(
                          _currentUserId, widget.userId!);
                    } else if (status == 'received') {
                      await provider.acceptFriendRequest(
                          widget.userId!, _currentUserId);
                    }
                    setState(() {}); // Refresh UI after action
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: status == 'received' ? Colors.green : Colors.blue,
            foregroundColor: Colors.white,
            disabledBackgroundColor: Colors.grey,
              shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12), // ⬅️ Adjust corner roundness here
  ),
          ),
          child: Text(_getButtonText(status)), // Dynamic button text
        );
      },
    );
  }

// Determine button text based on status
  String _getButtonText(String status) {
    switch (status) {
      case 'none':
        return 'Send Friend Request';
      case 'sent':
        return 'Request Sent';
      case 'received':
        return 'Accept Request';
      case 'friends':
        return 'Friends';
      default:
        return 'Send Friend Request';
    }
  }

  Widget _buildProfileHeader(
      Map<String, dynamic> profile, BuildContext context) {
    return Container(
      color: tealSwatch.withOpacity(0.1),
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundImage: profile['profileImage'] != null &&
                    profile['profileImage'].isNotEmpty
                ? NetworkImage(profile['profileImage'])
                : const AssetImage('assets/images/profile.png')
                    as ImageProvider,
          ),
          const SizedBox(height: 16),
          Text(
            profile['username'] ?? 'User',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (_isCurrentUser ||
              profile['isPublic'] ||
              profile['areFriends']) ...[
            const SizedBox(height: 8),
            if (profile['location'] != null && profile['location'].isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Colors.grey),
                  const SizedBox(width: 4),
                  Text(
                    profile['location'],
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
          ],
          const SizedBox(height: 16),

          // Show Friend Action & Chat Button only if it's NOT the current user
          if (!_isCurrentUser) ...[
            Row(

                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
              children: [


             
            _buildFriendActionButton(profile),
            const SizedBox(width: 12),
            SizedBox(
              width: 100,
              height: 40,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    '/chat', // Replace with the actual route name
                    arguments: {
                      'userId': profile['id'] ?? '', // Ensure it's not null
                      'username':
                          profile['username'] ?? 'Unknown', // Default username
                      'profileImage': profile['profileImage'] ??
                          '', // Handle null profile image
                    },
                  );
                },
                // icon: const Icon(Icons.chat, size: 20),
                label: const Text("Chat"),
                style: ElevatedButton.styleFrom(
                  foregroundColor: tealColor,
                  backgroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
             ],
            )
          ],
        ],
      ),
    );
  }

  Widget _buildFriendActionButton(Map<String, dynamic> profile) {
    // Get the FriendRequestProvider
    final friendRequestProvider =
        Provider.of<FriendRequestProvider>(context, listen: false);

    // Already friends: show Unfriend button
    if (profile['areFriends'] ?? false) {
      return ElevatedButton.icon(
        onPressed: () {
          // Confirm unfriend action
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Unfriend'),
              content: Text(
                  'Are you sure you want to unfriend ${profile['username']}?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    try {
                      await friendRequestProvider.unfriendUser(
                          _currentUserId, widget.userId!);
                      setState(() {
                        profile['areFriends'] = false;
                      });
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Unfriended successfully')),
                      );
                    } catch (e) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed to unfriend: $e')),
                      );
                    }
                  },
                  child: const Text('Unfriend'),
                ),
              ],
            ),
          );
        },
        // icon: const Icon(Icons.person_remove),
     
        label: const Text('Unfriend'),
        style: ElevatedButton.styleFrom(
          backgroundColor: tealColor,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        ),)
      );
    }
    // Friend request already sent: show disabled Request Sent button
    else if (profile['friendRequestSent'] ?? false) {
      return ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.pending),
        label: const Text('Request Sent'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.grey,
          foregroundColor: Colors.white,
        ),
      );
    }
    // Not friends: show Add Friend button
    else {
      return ElevatedButton.icon(
        onPressed: () async {
          try {
            // Send friend request using FriendRequestProvider
            await friendRequestProvider.sendFriendRequest(
                _currentUserId, widget.userId!);
            setState(() {
              profile['friendRequestSent'] = true;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Friend request sent successfully')),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to send friend request: $e')),
            );
          }
        },
        // icon: const Icon(Icons.person_add),
        label: const Text('Add Friend'),
        style: ElevatedButton.styleFrom(
          backgroundColor:
              tealSwatch, // Make sure tealSwatch is defined in your project
          foregroundColor: Colors.white,
        ),
      );
    }
  }

  Widget _buildStatsSection(Map<String, dynamic> profile) {
    print(profile);
    print(profile['friendsCount']);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildStatItem(
            'Trips',
            profile['tripCount']?.toString() ?? '0',
            // Icons.map,
          ),
          _buildStatItem(
            'Friends',
            profile['friendsCount']?.toString() ?? '0',
            // Icons.people,
            onTap: () => _showFriendsList(profile['friendsDetails'] ?? []),
          ),
          _buildStatItem(
            'Photos',
            profile['photoCount']?.toString() ?? '0',
            // Icons.photo_library,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          children: [
            // Icon(icon, color: tealSwatch),
            // const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showFriendsList(List<Map<String, dynamic>> friends) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Friends',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: friends.isEmpty
                    ? const Center(child: Text('No friends yet'))
                    : ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: friend['profileImage'] != null &&
                                      friend['profileImage'].isNotEmpty
                                  ? NetworkImage(friend['profileImage'])
                                  : null,
                              child: friend['profileImage'] == null ||
                                      friend['profileImage'].isEmpty
                                  ? const Icon(Icons.person)
                                  : null,
                            ),
                            title: Text(friend['username']),
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ViewProfileScreen(
                                      userId: friend['userId']),
                                ),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
Widget _buildTripsSection(Map<String, dynamic> profile) {
  final trips = profile['trips'] as List<dynamic>? ?? [];
  final tripImages = profile['tripImages'] as Map<String, List<dynamic>>? ?? {};

  void removeTrip(String tripId) {
    setState(() {
      trips.removeWhere((trip) => trip['tripId'] == tripId);
    });
  }

  // Sort the trips by 'created_at' (ISO 8601 format)
  trips.sort((a, b) {
    final dateA = DateTime.tryParse(a['created_at'] ?? '');
    final dateB = DateTime.tryParse(b['created_at'] ?? '');

    if (dateA == null || dateB == null) return 0; // Handle case where date is missing or invalid
    return dateB.compareTo(dateA); // Sort in descending order (most recent first)
  });

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Recent Trips',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          // if (trips.isNotEmpty)
          //   TextButton(
          //     onPressed: () {
          //       // Navigate to all trips
          //     },
          //     child: const Text('See All'),
          //   ),
        ],
      ),
      const SizedBox(height: 8),
      if (trips.isEmpty)
        _buildEmptyTripsPlaceholder()
      else
        SizedBox(
          height: 220,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: trips.length,
            itemBuilder: (context, index) {
              final trip = trips[index];
              final String tripId = trip['tripId'];

              // Fetch image list for this trip
              final List<dynamic> imagesForTrip = tripImages[tripId] ?? [];

              // Extract image_url from first image if available
              String? coverPhoto;
              if (imagesForTrip.isNotEmpty) {
                final firstImage = imagesForTrip.first;
                if (firstImage is Map && firstImage['image_url'] != null) {
                  coverPhoto = firstImage['image_url'] as String?;
                }
              }

              return TripCard(
                trip: trip,
                isCurrentUser: _isCurrentUser,
                onTripDeleted: removeTrip,
                coverPhoto: coverPhoto, // Will be null if not available
              );
            },
          ),
        ),
    ],
  );
}




Widget _buildEmptyTripsPlaceholder() {
  return Container(
    height: 200,
    decoration: BoxDecoration(
      color: Colors.grey[100],
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            'No trips yet',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    ),
  );
}

Widget _buildPhotosSection(Map<String, dynamic> profile) {
  final tripImages = profile['tripImages'] as Map<String, List<dynamic>>? ?? {};
  final tripNames = profile['tripNames'] as Map<String, String>? ?? {};

print('trip images---- $tripImages');


  if (tripImages.isEmpty) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_library_outlined, size: 48, color: Colors.grey),
            SizedBox(height: 8),
            Text('No photos yet', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  // Convert tripImages to match the expected format for PhotoGrid
  final Map<String, List<Map<String, String>>> tripPhotos = tripImages.map((tripId, photos) {
    List<Map<String, String>> imageMaps = photos.map((photo) {
      return {
        'id': photo['image_id']?.toString() ?? '', // Ensure 'id' is a string
      'url': photo['image_url'] as String? ?? PhotoGrid.placeholderImage,
      'tripName': tripNames[tripId] ?? 'Unnamed Trip', // Add trip name inside image data
      };
    }).toList();

     return MapEntry(tripId, imageMaps); // Keep tripId as the key
  });
print("Trip Photos: $tripPhotos");
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 10),
        child: Text(
          'Photos',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
      
      PhotoGrid(tripPhotos: tripPhotos), // Pass formatted tripPhotos to PhotoGrid
    ],
  );
}
}