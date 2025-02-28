import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/user_model.dart';


class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<UserModel>> searchUsersByName(String searchQuery) async {
    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .where('username', isEqualTo: searchQuery)
        .get();

    return snapshot.docs.map((doc) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  Future<List<UserModel>> findNearbyUsers(LatLng userLocation, double radiusInKm) async {
    QuerySnapshot snapshot = await _firestore.collection('users').get();

    return snapshot.docs.map((doc) {
      UserModel user = UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
      double distance = calculateDistance(
        userLocation.latitude,
        userLocation.longitude,
        user.location.latitude,
        user.location.longitude,
      );
      return distance <= radiusInKm ? user : null;
    }).whereType<UserModel>().toList();
  }

  double calculateDistance(lat1, lon1, lat2, lon2) {
    const double R = 6371; // Earth's radius in km
    double dLat = (lat2 - lat1) * (3.141592653589793 / 180.0);
    double dLon = (lon2 - lon1) * (3.141592653589793 / 180.0);
    double a = (sin(dLat / 2) * sin(dLat / 2)) +
        cos(lat1 * (3.141592653589793 / 180.0)) *
            cos(lat2 * (3.141592653589793 / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c; // Distance in km
  }
}
