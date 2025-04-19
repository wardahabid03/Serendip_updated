import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:serendip/models/ads_model.dart';


class BusinessAdsProvider with ChangeNotifier {
  final _adsRef = FirebaseFirestore.instance.collection('business_ads');
  List<BusinessAd> _ads = [];

  List<BusinessAd> get ads => _ads;

  Future<void> fetchAds({GeoPoint? userLocation}) async {
    final snapshot = await _adsRef
        .where('isPaymentActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .get();

    _ads = snapshot.docs.map((doc) {
      final ad = BusinessAd.fromDoc(doc);
      if (userLocation != null) {
        final distance = _calculateDistance(
          userLocation.latitude,
          userLocation.longitude,
          ad.location.latitude,
          ad.location.longitude,
        );
        return ad.copyWith(distance: distance);
      }
      return ad;
    }).toList();

    if (userLocation != null) {
      _ads.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
    }

    notifyListeners();
  }

  Future<void> addAd(BusinessAd ad) async {
    final doc = _adsRef.doc();
    await doc.set(ad.toMap());
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371; // km
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = 
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) *
        (sin(dLon / 2) * sin(dLon / 2));
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * (pi / 180);
}
