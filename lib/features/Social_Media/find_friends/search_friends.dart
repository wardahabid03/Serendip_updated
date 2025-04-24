import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("user_locations");

  // 🔍 Search users by username (case-insensitive)
  Future<List<UserModel>> searchUsersByName(String searchQuery) async {
    if (searchQuery.isEmpty) return [];

    final lowercasedQuery = searchQuery.toLowerCase();

    QuerySnapshot snapshot = await _firestore
        .collection('users')
        .orderBy('username')
        .startAt([lowercasedQuery])
        .endAt([lowercasedQuery + '\uf8ff'])
        .get();

    return snapshot.docs.map((doc) {
      return UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
    }).toList();
  }

  // 📍 Find nearby users within a certain radius
  Future<List<UserModel>> findNearbyUsers(LatLng currentUserLocation, double radiusKm) async {
    print("🔍 Fetching user locations from Firebase...");
    final snapshot = await _dbRef.get();

    if (!snapshot.exists) {
      print("⚠ No user locations found!");
      return [];
    }

    Map<String, dynamic> userLocations;
    try {
      userLocations = (snapshot.value as Map<Object?, Object?>).cast<String, dynamic>();
    } catch (e) {
      print("❌ Error casting Firebase data: $e");
      return [];
    }

    print("📌 Retrieved ${userLocations.length} user locations from Firebase");

    List<UserModel> nearbyUsers = [];

    for (var entry in userLocations.entries) {
      String userId = entry.key;
      print("👤 Processing user: $userId");

      if (entry.value is Map) {
        Map<String, dynamic> locationData;
        try {
          locationData = (entry.value as Map<Object?, Object?>).cast<String, dynamic>();
        } catch (e) {
          print("❌ Error casting location data for user $userId: $e");
          continue;
        }

        if (locationData.containsKey('latitude') && locationData.containsKey('longitude')) {
          double lat = locationData['latitude'];
          double lng = locationData['longitude'];

          print("📍 User $userId Location: ($lat, $lng)");

          double distance = calculateDistance(
            currentUserLocation.latitude,
            currentUserLocation.longitude,
            lat,
            lng,
          );

          print("📏 Distance to user $userId: ${distance.toStringAsFixed(2)} km");

          if (distance <= radiusKm) {
            print("✅ User $userId is within range!");

            try {
              DocumentSnapshot userSnapshot =
                  await _firestore.collection('users').doc(userId).get();

              if (userSnapshot.exists) {
                Map<String, dynamic> userData =
                    userSnapshot.data() as Map<String, dynamic>;

                if (!(userData['locationEnabled'] ?? false)) {
                  print("🚫 Skipping user $userId (location not enabled)");
                  continue;
                }

                print("📄 Retrieved Firestore data for user $userId");

                nearbyUsers.add(UserModel(
                  userId: userId,
                  username: userData['username'] ?? 'Unknown',
                  email: userData['email'] ?? '',
                  profileImage: userData['profileImage'],
                  dob: userData['dob'],
                  bio: userData['bio'],
                  isPublic: userData['isPublic'] ?? true,
                  locationEnabled: userData['locationEnabled'] ?? false,
                  friends: List<String>.from(userData['friends'] ?? []),
                  trips: List<String>.from(userData['trips'] ?? []),
                  privacySettings: PrivacySettings.fromMap(userData['privacySettings'] ?? {}),
                  location: LatLng(lat, lng),
                  isProfileComplete: userData['isProfileComplete'] ?? false,
                  updatedAt: (userData['updatedAt'] != null)
                      ? (userData['updatedAt'] as Timestamp).toDate()
                      : null,
                  tripCount: userData['tripCount'] ?? 0,
                  friendCount: userData['friendCount'] ?? 0,
                  photoCount: userData['photoCount'] ?? 0,
                  isFriend: false,
                ));
              } else {
                print("⚠ Firestore document not found for user $userId");
              }
            } catch (e) {
              print("❌ Error fetching Firestore data for user $userId: $e");
            }
          } else {
            print("❌ User $userId is out of range.");
          }
        } else {
          print("⚠ Skipping user $userId due to missing location data.");
        }
      } else {
        print("⚠ Skipping user $userId due to invalid data format.");
      }
    }

    print("✅ Found ${nearbyUsers.length} nearby users.");
    return nearbyUsers;
  }

  Future<List<UserModel>> getAllUsers() async {
  final snapshot = await _dbRef.get();

  if (!snapshot.exists) {
    print("⚠ No user locations found!");
    return [];
  }

  Map<String, dynamic> userLocations;
  try {
    userLocations = (snapshot.value as Map<Object?, Object?>).cast<String, dynamic>();
  } catch (e) {
    print("❌ Error casting Firebase data: $e");
    return [];
  }

  List<UserModel> allUsers = [];

  for (var entry in userLocations.entries) {
    String userId = entry.key;

    if (entry.value is Map) {
      Map<String, dynamic> locationData;
      try {
        locationData = (entry.value as Map<Object?, Object?>).cast<String, dynamic>();
      } catch (e) {
        print("❌ Error casting location data for user $userId: $e");
        continue;
      }

      if (locationData.containsKey('latitude') && locationData.containsKey('longitude')) {
        double lat = locationData['latitude'];
        double lng = locationData['longitude'];

        try {
          DocumentSnapshot userSnapshot = await _firestore.collection('users').doc(userId).get();
          if (userSnapshot.exists) {
            Map<String, dynamic> userData = userSnapshot.data() as Map<String, dynamic>;

            if (!(userData['locationEnabled'] ?? false)) {
              continue;
            }

            allUsers.add(UserModel(
              userId: userId,
              username: userData['username'] ?? 'Unknown',
              email: userData['email'] ?? '',
              profileImage: userData['profileImage'],
              dob: userData['dob'],
              bio: userData['bio'],
              isPublic: userData['isPublic'] ?? true,
              locationEnabled: userData['locationEnabled'] ?? false,
              friends: List<String>.from(userData['friends'] ?? []),
              trips: List<String>.from(userData['trips'] ?? []),
              privacySettings: PrivacySettings.fromMap(userData['privacySettings'] ?? {}),
              location: LatLng(lat, lng), // ✅ valid location
              isProfileComplete: userData['isProfileComplete'] ?? false,
              updatedAt: (userData['updatedAt'] != null)
                  ? (userData['updatedAt'] as Timestamp).toDate()
                  : null,
              tripCount: userData['tripCount'] ?? 0,
              friendCount: userData['friendCount'] ?? 0,
              photoCount: userData['photoCount'] ?? 0,
              isFriend: false,
            ));
          }
        } catch (e) {
          print("❌ Error fetching user $userId: $e");
        }
      }
    }
  }

  print("✅ Fetched ${allUsers.length} users with valid location.");
  return allUsers;
}


  // 📐 Calculate distance between two lat/lng pairs (Haversine)
  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double R = 6371; // Earth's radius in kilometers
    double dLat = (lat2 - lat1) * (pi / 180.0);
    double dLon = (lon2 - lon1) * (pi / 180.0);
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180.0)) *
            cos(lat2 * (pi / 180.0)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}
