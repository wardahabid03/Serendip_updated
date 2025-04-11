import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudinary/cloudinary.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
 import 'package:geocoding/geocoding.dart';

class ProfileProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  int _friendsCount = 0;
  List<Map<String, dynamic>> _friendsDetails = [];

  List<Map<String, dynamic>> get friendsDetails => _friendsDetails;
  String get currentUserId => _auth.currentUser?.uid ?? '';

  Map<String, dynamic> _userProfile = {};
  Map<String, dynamic> get userProfile => _userProfile;

  final cloudinary = Cloudinary.signedConfig(
    apiKey: '935742635189255',
    apiSecret: 'u_1cFQsYmXSrXoDL_6gJbQWvQcA',
    cloudName: 'dup7xznsc',
  );

  final ImagePicker _picker = ImagePicker();
  bool _isProfileComplete = false;

  bool get isProfileComplete => _isProfileComplete;

  Map<String, String?> _profileImageCache = {}; 

  Future<String?> pickAndUploadImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
      );

      if (pickedFile == null) return null;

      final imageFile = File(pickedFile.path);

      final response = await cloudinary.upload(
        file: imageFile.path,
        fileBytes: await imageFile.readAsBytes(),
        resourceType: CloudinaryResourceType.image,
        folder: 'user_profiles',
      );

      if (response.isSuccessful) {
        return response.secureUrl;
      } else {
        throw Exception('Failed to upload image to Cloudinary');
      }
    } catch (e) {
      throw Exception('Error uploading image: ${e.toString()}');
    }
  }

  Future<void> saveUserProfile({
    required String username,
    required String email,
    required String dob,
    required bool isPublic,
    required String profileImage,
    required bool locationEnabled,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      if (username.isEmpty) throw Exception('Username is required');
      if (email.isEmpty) throw Exception('Email is required');
      if (dob.isEmpty) throw Exception('Date of birth is required');

      final profileData = {
        'username': username,
        'email': email,
        'dob': dob,
        'isPublic': isPublic,
        'profileImage': profileImage,
        'locationEnabled': locationEnabled,
        'updatedAt': FieldValue.serverTimestamp(),
        'isProfileComplete': true,
      };

      await _firestore.collection('users').doc(user.uid).set(profileData);

      _isProfileComplete = true;
      notifyListeners();
    } catch (e) {
      throw Exception('Failed to save profile: ${e.toString()}');
    }
  }




Future<Map<String, dynamic>> fetchUserProfile({String? userId}) async {
  try {
    final String uid = userId ?? _auth.currentUser?.uid ?? '';

    if (uid.isEmpty) {
      throw Exception('User not logged in');
    }

    final snapshot = await _firestore.collection('users').doc(uid).get();

    if (!snapshot.exists) {
      if (userId == null) {
        _isProfileComplete = false;
        notifyListeners();
      }
      return {};
    }

    final data = snapshot.data() as Map<String, dynamic>;

    List<Map<String, dynamic>> trips = await fetchUserTrips(userId: uid);

    Map<String, String> tripNames = {};
    for (var trip in trips) {
      tripNames[trip['tripId']] = trip['trip_name'] ?? 'Unnamed Trip';
    }

    Map<String, List<Map<String, dynamic>>> tripImages = {};
    int photoCount = 0;

    for (var trip in trips) {
      String tripId = trip['tripId'] as String;
      List<Map<String, dynamic>> images = await fetchTripImages(tripId);
      tripImages[tripId] = images;
      photoCount += images.length;
    }

    _isProfileComplete = data['isProfileComplete'] ?? false;
    int friendsCount = await _countFriends(uid);
    List<Map<String, dynamic>> friendsDetails = await fetchFriendsDetails(uid);
    bool areFriends = await _checkIfFriends(uid);

    /// 🔥 Fetch current location from Realtime Database
    final locationSnapshot = await FirebaseDatabase.instance
        .ref('user_locations/$uid')
        .get();

    Map<String, dynamic>? currentLocation;
    String? readableLocation;

    if (locationSnapshot.exists) {
      final locData = locationSnapshot.value as Map;
      final double latitude = locData['latitude'];
      final double longitude = locData['longitude'];

      currentLocation = {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': locData['timestamp'],
      };

      try {
        List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
        if (placemarks.isNotEmpty) {
          Placemark place = placemarks.first;
          readableLocation = place.subLocality?.isNotEmpty == true
              ? place.subLocality
              : place.locality ?? '';

              print(place.locality);
        }
      } catch (e) {
        readableLocation = '';
      }
    }

    _userProfile = {
      ...data,
      'friendsCount': friendsCount,
      'friendsDetails': friendsDetails,
      'areFriends': areFriends,
      'tripIds': tripNames.keys.toList(),
      'trips': trips,
      'tripImages': tripImages,
      'tripNames': tripNames,
      'photoCount': photoCount,
      'currentLocation': currentLocation,
      'location': readableLocation, // ✅ Added displayable name here
    };

    notifyListeners();
    return _userProfile;
  } catch (e) {
    throw Exception('Failed to fetch profile: ${e.toString()}');
  }
}


  Future<List<Map<String, dynamic>>> fetchTripImages(String tripId) async {
    try {
      final snapshot = await _firestore
          .collection('trips')
          .doc(tripId)
          .collection('images')
          .get();

      return snapshot.docs.map((doc) {
        return {
          'image_id': doc['image_id'],
          'image_url': doc['image_url'],
          'latitude': doc['latitude'],
          'longitude': doc['longitude'],
          'timestamp': doc['timestamp'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchUserTrips({required String userId}) async {
    try {
      final userSnapshot = await _firestore.collection('users').doc(userId).get();

      if (!userSnapshot.exists || userSnapshot.data()?['trips'] == null) {
        return [];
      }

      List<String> tripIds = List<String>.from(userSnapshot.data()?['trips'] ?? []);

      if (tripIds.isEmpty) {
        return [];
      }

      final tripSnapshot = await _firestore.collection('trips')
          .where(FieldPath.documentId, whereIn: tripIds)
          .get();

      return tripSnapshot.docs.map((doc) {
        return {
          'tripId': doc.id,
          ...doc.data(),
        };
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch trips: ${e.toString()}');
    }
  }

  Future<bool> _checkIfFriends(String otherUserId) async {
    try {
      final String currentUserId = _auth.currentUser?.uid ?? '';
      if (currentUserId.isEmpty || otherUserId.isEmpty) return false;

      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(otherUserId)
          .get();

      return friendsSnapshot.exists;
    } catch (e) {
      return false;
    }
  }

  Future<int> _countFriends(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .get();

      return snapshot.size;
    } catch (e) {
      return 0;
    }
  }

  Future<List<Map<String, dynamic>>> fetchFriendsDetails(String userId) async {
    List<Map<String, dynamic>> friendsDetails = [];
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    String? cachedFriends = prefs.getString('friends_$userId');
    if (cachedFriends != null) {
      try {
        List<dynamic> cachedList = jsonDecode(cachedFriends);
        friendsDetails = List<Map<String, dynamic>>.from(cachedList);
        _friendsDetails = friendsDetails;
        notifyListeners();
      } catch (e) {}
    }

    try {
      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('friends')
          .get();

      List<Map<String, dynamic>> freshFriends = [];

      for (var doc in friendsSnapshot.docs) {
        final friendId = doc.id;
        final friendProfile = await _firestore.collection('users').doc(friendId).get();
        if (friendProfile.exists) {
          final friendInfo = friendProfile.data() as Map<String, dynamic>;
          final friendData = {
            'userId': friendId,
            'username': friendInfo['username'] ?? 'Unknown',
            'profileImage': friendInfo['profileImage'] ?? '',
          };
          freshFriends.add(friendData);
        }
      }

      if (jsonEncode(freshFriends) != cachedFriends) {
        await prefs.setString('friends_$userId', jsonEncode(freshFriends));
      }

      _friendsDetails = freshFriends;
      notifyListeners();

      return freshFriends;
    } catch (e) {
      return friendsDetails;
    }
  }

  Future<bool> checkProfileComplete() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final snapshot = await _firestore.collection('users').doc(user.uid).get();
      if (!snapshot.exists) return false;

      final data = snapshot.data() as Map<String, dynamic>;
      _isProfileComplete = data['isProfileComplete'] ?? false;
      notifyListeners();

      return _isProfileComplete;
    } catch (e) {
      return false;
    }
  }

  bool isValidDate(String date) {
    try {
      DateTime.parse(date);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<String?> autofillEmail() async {
    try {
      final user = _auth.currentUser;
      return user?.email;
    } catch (e) {
      return null;
    }
  }

  Future<String> getUsernameById(String userId) async {
    try {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        return userDoc['username'] ?? 'Unknown';
      } else {
        return 'Unknown';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  Future<void> updateSetting(String key, dynamic value) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      await _firestore.collection('users').doc(user.uid).update({
        key: value,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (key == 'isProfileComplete') {
        _isProfileComplete = value;
      }

      notifyListeners();
    } catch (e) {
      throw Exception('Failed to update setting: ${e.toString()}');
    }
  }

 // Get the profile image URL for a given userId, with caching
  Future<String?> getProfileImageById(String userId) async {
    // Check if the image is already cached
    if (_profileImageCache.containsKey(userId)) {
      return _profileImageCache[userId];
    }

    try {
      // Fetch from Firestore if not cached
      final userSnapshot = await _firestore.collection('users').doc(userId).get();

      if (userSnapshot.exists) {
        final userData = userSnapshot.data() as Map<String, dynamic>;
        String? profileImageUrl = userData['profileImage'];

        // Cache the result
        _profileImageCache[userId] = profileImageUrl;

        return profileImageUrl; // Return the profile image URL or null if not found
      } else {
        throw Exception('User not found');
      }
    } catch (e) {
      throw Exception('Failed to fetch profile image: ${e.toString()}');
    }
  }

}
