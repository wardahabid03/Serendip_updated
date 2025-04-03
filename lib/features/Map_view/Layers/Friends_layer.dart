import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:serendip/models/user_model.dart';
import '../../../core/utils/image_markers.dart';
import 'map_layer.dart';

class FriendsLayer extends MapLayer {
  final Set<Marker> _friendMarkers = {};

  void updateFriendLocations(BuildContext context, List<UserModel> friends) async {
    print("🔄 Updating friend locations with ${friends.length} friends");
    final Set<Marker> newMarkers = {};

    for (var friend in friends) {
      try {
        BitmapDescriptor markerIcon;
        if (friend.profileImage != null && friend.profileImage!.isNotEmpty) {
          markerIcon = await CustomMarkerHelper.getCustomMarker(friend.profileImage!);
        } else {
          markerIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
        }

        final marker = Marker(
          markerId: MarkerId('friend_${friend.userId}'),
          position: friend.location,
          infoWindow: InfoWindow(
           
            title: friend.username,
  
          ),
          icon: markerIcon,
          onTap: () {  
            Navigator.pushNamed(
              context,  // ✅ Now context is available
              '/view_profile',
              arguments: friend.userId,
            );
          },
          // anchor: Offset(0.5, 0.5), // Center the marker
          // alpha: 0.5, // Transparency
          // rotation: 90.0, // Rotates marker
        );

        newMarkers.add(marker);
        print("✅ Added marker for friend ${friend.username}");
      } catch (e) {
        print("❌ Error creating marker for friend ${friend.username}: $e");
        continue;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _friendMarkers.clear();
      _friendMarkers.addAll(newMarkers);
      notifyListeners();
    });
  }

  @override
  Set<Marker> getMarkers() {
    return Set<Marker>.from(_friendMarkers);
  }

  @override
  void clear() {
    _friendMarkers.clear();
    notifyListeners();
  }

  @override
  Set<Circle> getCircles() => {};

  @override
  Set<Polyline> getPolylines() => {};

  @override
  void onTap(LatLng position) {
    debugPrint("FriendLayer tapped at: $position");
  }
}
