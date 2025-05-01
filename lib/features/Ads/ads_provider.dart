import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:serendip/models/ads_model.dart';


class BusinessAdsProvider with ChangeNotifier {
  final _adsRef = FirebaseFirestore.instance.collection('business_ads');
  List<BusinessAd> _ads = [];

  List<BusinessAd> get ads => _ads;

Future<void> fetchAds({GeoPoint? userLocation}) async {
  print("Fetching ads from Firestore...");
  final snapshot = await _adsRef
      .where('isPaymentActive', isEqualTo: true)
      .orderBy('createdAt', descending: true)
      .get();

  print("Found ${snapshot.docs.length} active ads.");

  _ads = snapshot.docs.map((doc) {
    final ad = BusinessAd.fromDoc(doc);
    print("Ad fetched: ${ad.title}");

    if (userLocation != null) {
      final distance = _calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        ad.location.latitude,
        ad.location.longitude,
      );
      print("Distance to ad '${ad.title}': ${distance.toStringAsFixed(2)} km");
      return ad.copyWith(distance: distance);
    }

    return ad;
  }).toList();

  if (userLocation != null) {
    print("Sorting ads by distance...");
    _ads.sort((a, b) => (a.distance ?? 0).compareTo(b.distance ?? 0));
  }

  print("Ads ready. Notifying listeners.");
  notifyListeners();
}


  Future<void> addAd(BusinessAd ad) async {
    final doc = _adsRef.doc();
    await doc.set(ad.toMap());
  }


Future<void> updateUserAdPaymentStatus({
  required String userId, // for searching, not doc id
  required String paymentPlan,
  required DateTime adStartDate,
  required DateTime adEndDate,
}) async {
  final query = await _adsRef.where('ownerId', isEqualTo: userId).limit(1).get();

  if (query.docs.isEmpty) {
    throw Exception('Ad not found for user: $userId');
  }

  final docId = query.docs.first.id;

  final adData = {
    'isPaymentActive': true,
    'paymentPlan': paymentPlan,
    'adStartDate': adStartDate,
    'adEndDate': adEndDate,
  };

  await _adsRef.doc(docId).set(adData, SetOptions(merge: true));
}

Future<void> incrementImpression(String adId) async {
  final docRef = _adsRef.doc(adId);
  await docRef.update({
    'impressionCount': FieldValue.increment(1),
  });
}

Future<void> incrementCtaClick(String adId) async {
  final docRef = _adsRef.doc(adId);
  await docRef.update({
    'ctaClickCount': FieldValue.increment(1),
  });
}

Future<Map<String, dynamic>?> fetchUserAd(String userId) async {
  final query = await _adsRef.where('ownerId', isEqualTo: userId).limit(1).get();

  if (query.docs.isNotEmpty) {
    return {
      'docId': query.docs.first.id,
      ...query.docs.first.data(),
    };
  }
  return null;
}

Future<void> deleteUserAd(String userId) async {
  final query = await _adsRef.where('ownerId', isEqualTo: userId).limit(1).get();

  if (query.docs.isNotEmpty) {
    await _adsRef.doc(query.docs.first.id).delete();
  } else {
    throw Exception("Ad not found for user $userId");
  }
}

Future<void> updateAd({required BusinessAd ad, File? newImageFile}) async {
  String imageUrl = ad.imageUrl;

  if (newImageFile != null) {
    final storageRef = FirebaseStorage.instance
        .ref()
        .child('ad_images')
        .child('${ad.id}.jpg');
    await storageRef.putFile(newImageFile);
    imageUrl = await storageRef.getDownloadURL();
  }

  final updatedData = ad.copyWith(imageUrl: imageUrl).toMap();
  updatedData.removeWhere((key, value) => value == null); // Clean nulls

  await _adsRef.doc(ad.id).update(updatedData);
  await fetchAds(); // Refresh UI
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
