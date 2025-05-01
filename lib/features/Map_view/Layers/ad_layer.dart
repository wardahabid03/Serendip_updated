import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:serendip/core/constant/colors.dart';
import 'package:serendip/core/utils/navigator_key.dart';
import 'package:serendip/models/ads_model.dart';
import 'package:url_launcher/url_launcher.dart'; // NEW import

import '../../../core/utils/image_markers.dart';
import 'map_layer.dart';

class AdLayer extends MapLayer {
  final Set<Marker> _adMarkers = {};
  final Set<Polyline> _routePolyline = {};
  LatLng? _userLocation;
  Timer? _bounceTimer;

  final String _apiKey = "AIzaSyC4gULFHsrb14nNcNzQNwZa6tG0HNBIwmg";

  final Map<String, LatLng> _bouncingMarkers = {}; // Only for no-image markers

  void setUserLocation(LatLng location) {
    _userLocation = location;
    notifyListeners();
  }

  Future<void> setAds(List<BusinessAd> ads) async {
    _adMarkers.clear();
    _bouncingMarkers.clear();
    _routePolyline.clear();
    _bounceTimer?.cancel(); // Cancel any previous timer

    for (var ad in ads) {
      final LatLng adLatLng = LatLng(ad.location.latitude, ad.location.longitude);
      BitmapDescriptor icon;

      if (ad.imageUrl.isNotEmpty) {
        icon = await CustomMarkerHelper.getCustomMarker(ad.imageUrl);
      } else {
        // Default marker if no image
        icon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
        _bouncingMarkers['ad_${ad.id}'] = adLatLng; // Track for bouncing
      }

_adMarkers.add(
  Marker(
    markerId: MarkerId('ad_${ad.id}'),
    position: adLatLng,
    icon: icon,
    infoWindow: InfoWindow(
      title: ad.title,

      // Remove onTap here if you want it to open on marker tap directly
    ),
   onTap: () async {
  await _onAdMarkerTapped(adLatLng);
  _showCTADialog(ad.cta!);
},

  ),
);

    

      // ✨ Directly draw route for the FIRST ad (you can adjust if you want all)
      if (_adMarkers.length == 1) {
        await _drawRouteToAd(adLatLng);
      }
    }

    _startBouncing();
    notifyListeners();
  }

  void _startBouncing() {
    if (_bouncingMarkers.isEmpty) return;

    bool goingUp = true;
    const double jumpHeight = 0.0035;
    _bounceTimer = Timer.periodic(const Duration(milliseconds: 700), (timer) {
      final updatedMarkers = <Marker>{};

      for (var marker in _adMarkers) {
        if (_bouncingMarkers.containsKey(marker.markerId.value)) {
          LatLng originalPos = _bouncingMarkers[marker.markerId.value]!;

          final LatLng newPos = goingUp
              ? LatLng(originalPos.latitude + jumpHeight, originalPos.longitude)
              : originalPos;

          updatedMarkers.add(
            Marker(
              markerId: marker.markerId,
              position: newPos,
              icon: marker.icon,
              infoWindow: marker.infoWindow,
              onTap: marker.onTap,
            ),
          );
        } else {
          updatedMarkers.add(marker);
        }
      }

      _adMarkers
        ..clear()
        ..addAll(updatedMarkers);

      goingUp = !goingUp;
      notifyListeners();
    });
  }

  Future<void> _onAdMarkerTapped(LatLng adLatLng) async {
    await _drawRouteToAd(adLatLng);
  }

  Future<void> _drawRouteToAd(LatLng adLocation) async {
    if (_userLocation == null) return;

    final String url = "https://maps.googleapis.com/maps/api/directions/json"
        "?origin=${_userLocation!.latitude},${_userLocation!.longitude}"
        "&destination=${adLocation.latitude},${adLocation.longitude}"
        "&key=$_apiKey";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'].isNotEmpty) {
          final String encodedPolyline = data['routes'][0]['overview_polyline']['points'];
          _addRoutePolyline(encodedPolyline);
        }
      } else {
        print("Failed to fetch directions: ${response.body}");
      }
    } catch (e) {
      print("Error fetching directions: $e");
    }
  }

  void _addRoutePolyline(String encodedPolyline) {
    PolylinePoints polylinePoints = PolylinePoints();
    List<PointLatLng> decodedPoints = polylinePoints.decodePolyline(encodedPolyline);
    List<LatLng> routePoints = decodedPoints
        .map((point) => LatLng(point.latitude, point.longitude))
        .toList();

    _routePolyline.clear();
    _routePolyline.add(
      Polyline(
        polylineId: const PolylineId("ad_route"),
        points: routePoints,
        color: Colors.blue,
        width: 5,
      ),
    );
    notifyListeners();
  }
void _showCTADialog(String cta) {
  // Need a context! So use the global navigatorKey if available
  final BuildContext context = navigatorKey.currentContext!;
  
  showDialog(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('Proceed?'),
        content: const Text('Do you want to proceed to the business link or contact?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(); // Close the dialog
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(dialogContext).pop(); // Close the dialog first
              await _launchCTA(cta); // Now launch the CTA
            },
            child: const Text('Proceed'),
          ),
        ],
      );
    },
  );
}

  // ✨ NEW - Launch WhatsApp, Website, Phone Dialer based on CTA
  Future<void> _launchCTA(String cta) async {
    Uri? url;

    if (cta.startsWith('+') || cta.startsWith('0') || cta.startsWith('9')) {
      // Phone number
      url = Uri.parse('tel:$cta');
    } else if (cta.contains('wa.me') || cta.contains('whatsapp')) {
      // WhatsApp link
      url = Uri.parse(cta);
    } else if (cta.startsWith('http')) {
      // Website
      url = Uri.parse(cta);
    } else {
      // Default: treat as website
      url = Uri.parse('https://$cta');
    }

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      print('Could not launch CTA: $cta');
    }
  }

  @override
  Set<Marker> getMarkers() => _adMarkers;

  @override
  Set<Circle> getCircles() => {};

  @override
  Set<Polyline> getPolylines() => _routePolyline;

  @override
  void clear() {
    _bounceTimer?.cancel();
    _bouncingMarkers.clear();
    _adMarkers.clear();
    _routePolyline.clear();
    _userLocation = null;
    notifyListeners();
  }

  @override
  void onTap(LatLng position) {
    // No-op
  }
}
