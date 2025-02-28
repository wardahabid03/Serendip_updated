import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:serendip/models/user_model.dart';
import 'map_layer.dart';

class FriendsLayer implements MapLayer {
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};
  final Set<Polyline> _polylines = {};
  List<UserModel> _friends = [];

  // Update friends data and their markers
  void updateFriends(List<UserModel> friends) {
    _friends = friends;
    _updateMarkers();
  }

  void _updateMarkers() {
    _markers.clear();
    for (var friend in _friends) {
      _markers.add(
        Marker(
          markerId: MarkerId('friend_${friend.userId}'),
          position: friend.location,
          infoWindow: InfoWindow(
            title: friend.username,
            // snippet: 'Last seen: ${friend.lastSeen}',
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        ),
      );
    }
  }

  @override
  Set<Marker> getMarkers() {
    return _markers;
  }

  @override
  Set<Circle> getCircles() {
    return _circles;
  }

  @override
  Set<Polyline> getPolylines() {
    return _polylines;
  }

  @override
  void clear() {
    _markers.clear();
    _circles.clear();
    _polylines.clear();
    _friends.clear();
  }

  @override
  void update() {
    _updateMarkers();
  }
  
  @override
  void onTap(LatLng position) {
    // TODO: implement onTap
  }
}