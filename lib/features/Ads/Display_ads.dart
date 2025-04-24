import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/core/constant/colors.dart';
import 'package:serendip/core/utils/bottom_nav_bar.dart';
import 'package:serendip/core/utils/navigator_key.dart';
import 'package:serendip/features/Ads/ads_provider.dart';
import 'package:serendip/features/Map_view/controller/map_controller.dart';
import 'package:serendip/features/Map_view/map_screen.dart';
import 'package:serendip/models/ads_model.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:geolocator/geolocator.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:geocoding/geocoding.dart';

import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/utils/navigation_controller.dart';

class DisplayAdScreen extends StatefulWidget {
  const DisplayAdScreen({Key? key}) : super(key: key);

  @override
  State<DisplayAdScreen> createState() => _DisplayAdScreenState();
}

class _DisplayAdScreenState extends State<DisplayAdScreen> {
  Timer? _timer;
  List<bool> _expanded = [];
  Set<String> _seenImpressions = {};
  Map<String, String> _areaNames = {}; // cache for area names
  static const String ADS_LAYER = 'ads_layer';
    int _selectedIndex = 2;

  @override
  void initState() {
    super.initState();
    _fetchAdsPeriodically();
  }



  void _onNavBarItemSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
    NavigationController.navigateToScreen(context, index);
  }

  
  void _fetchAdsPeriodically() async {
    await _fetchAds();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _fetchAds());
  }

  Future<void> _fetchAds() async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    await Provider.of<BusinessAdsProvider>(context, listen: false).fetchAds(
      userLocation: GeoPoint(position.latitude, position.longitude),
    );

    final ads = context.read<BusinessAdsProvider>().ads;
    _expanded = List.generate(ads.length, (_) => false);

    // Preload area names
    for (final ad in ads) {
      if (ad.location != null && !_areaNames.containsKey(ad.id)) {
        final area =
            await _getAreaName(ad.location.latitude, ad.location.longitude);
        _areaNames[ad.id!] = area;
      }
    }

    setState(() {});
  }

  Future<String> _getAreaName(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        return '${p.locality ?? p.subAdministrativeArea ?? 'Area'}, ${p.administrativeArea ?? ''}';
      }
    } catch (e) {
      debugPrint("Geocoding error: $e");
    }
    return 'Unknown Area';
  }

  Future<void> _incrementImpression(String adId) async {
    final docRef =
        FirebaseFirestore.instance.collection('business_ads').doc(adId);
    await docRef.update({'impressions': FieldValue.increment(1)});
  }

  Future<void> _incrementCtaClick(String adId) async {
    final docRef =
        FirebaseFirestore.instance.collection('business_ads').doc(adId);
    await docRef.update({'ctaClicks': FieldValue.increment(1)});
  }

  void _toggleExpand(int index, String adId) {
    setState(() {
      _expanded[index] = !_expanded[index];
    });

    if (_expanded[index]) {
      _incrementCtaClick(adId);
    }
  }

  void _launchCallToAction(String callToAction) async {
    final uri = Uri.tryParse(callToAction);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _navigateToMap(LatLng destination) {
    final context = navigatorKey.currentState!.context;
    final mapController = Provider.of<MapController>(context, listen: false);
    mapController.toggleLayer(ADS_LAYER, true);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MapScreen(
          adLocation: destination,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ads = context.watch<BusinessAdsProvider>().ads;

    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Ads')),
      body:Stack(
      children: [
      
       ListView.builder(
        itemCount: ads.length,
        itemBuilder: (context, index) {
          final ad = ads[index];
          final isExpanded = _expanded.length > index && _expanded[index];
          final areaName = _areaNames[ad.id] ?? 'Loading area...';

          return VisibilityDetector(
            key: Key('ad-${ad.id}'),
            onVisibilityChanged: (info) {
              if (info.visibleFraction > 0.5 &&
                  !_seenImpressions.contains(ad.id)) {
                _incrementImpression(ad.id!);
                _seenImpressions.add(ad.id!);
              }
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: tealColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                        child: SizedBox(
                          height: 140,
                          width: double.infinity,
                          child: Image.network(
                            ad.imageUrl,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white70,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: IconButton(
                            icon: Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              size: 26,
                              color: Colors.black87,
                            ),
                            onPressed: () => _toggleExpand(index, ad.id!),
                          ),
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeInOut,
                    child: isExpanded
                        ? Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            ad.title ?? 'Sponsored Ad',
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          if (ad.description != null &&
                                              ad.description!.isNotEmpty)
                                            Text(
                                              ad.description!,
                                              style: const TextStyle(
                                                fontSize: 14,
                                                color: Colors.white,
                                                height: 1.4,
                                              ),
                                            ),
                                          const SizedBox(height: 16),
                                          Row(
                                            children: [
                                              const Icon(Icons.location_on,
                                                  size: 18,
                                                  color: Colors.redAccent),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  areaName,
                                                  style: const TextStyle(
                                                    color: Colors.white70,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (ad.cta != null && ad.cta!.isNotEmpty)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(left: 12),
                                        child: Column(
                                          children: [
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 10),
                                                backgroundColor: Colors.white,
                                                foregroundColor: tealColor,
                                                elevation: 1,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              onPressed: () =>
                                                  _launchCallToAction(ad.cta!),
                                              child: const Text("Contact Now"),
                                            ),
                                            const SizedBox(height: 8),
                                            ElevatedButton.icon(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.white,
                                                foregroundColor: tealColor,
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 12,
                                                        vertical: 10),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(12),
                                                ),
                                              ),
                                              onPressed: () => _navigateToMap(
                                                LatLng(ad.location!.latitude,
                                                    ad.location!.longitude),
                                              ),
                                              label: const Text('View on Map'),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                ],
                            ),
                          )
                        : const SizedBox.shrink(),
                  ),
                ],
               ),
              ),
            );
          },
        ),

        // Bottom navigation bar correctly positioned
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
  );
}
}