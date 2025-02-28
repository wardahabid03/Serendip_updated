import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloudinary/cloudinary.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';

class ProfileProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  int _friendsCount = 0;

  final cloudinary = Cloudinary.signedConfig(
    apiKey: '935742635189255',
    apiSecret: 'u_1cFQsYmXSrXoDL_6gJbQWvQcA',
    cloudName: 'dup7xznsc',
  );

  final ImagePicker _picker = ImagePicker();
  bool _isProfileComplete = false;

  bool get isProfileComplete => _isProfileComplete;

  Future<String?> pickAndUploadImage() async {
    try {
      final pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Compress image
      );
      
      if (pickedFile == null) return null;

      final imageFile = File(pickedFile.path);

      final response = await cloudinary.upload(
        file: imageFile.path,
        fileBytes: await imageFile.readAsBytes(),
        resourceType: CloudinaryResourceType.image,
        folder: 'user_profiles', // Organize images in a folder
        // transformation: 'w_500,h_500,c_fill', // Resize and crop to square
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

      // Validate data
      if (username.isEmpty) throw Exception('Username is required');
      if (email.isEmpty) throw Exception('Email is required');
      if (dob.isEmpty) throw Exception('Date of birth is required');
      // if (!locationEnabled) throw Exception('Location must be enabled');

      // Create profile data
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

      // Update Firestore
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
      print("No user ID provided and no user is logged in.");
      throw Exception('User not logged in');
    }

    print("Fetching profile for user: $uid");

    // Fetch user document
    final snapshot = await _firestore.collection('users').doc(uid).get();

    if (!snapshot.exists) {
      print("Profile not found for user: $uid. Assuming incomplete profile.");
      if (userId == null) {
        _isProfileComplete = false;
        notifyListeners();
      }
      return {};
    }

    final data = snapshot.data() as Map<String, dynamic>;

    // Fetch user's trips
    List<Map<String, dynamic>> trips = await fetchUserTrips(userId: uid);

    // Fetch friends count and details
    _isProfileComplete = data['isProfileComplete'] ?? false;
    int friendsCount = await _countFriends(uid);
    List<Map<String, dynamic>> friendsDetails = await fetchFriendsDetails(uid);

    // Check if the logged-in user is friends with the profile user
    bool areFriends = await _checkIfFriends(uid);

    print("Profile fetched successfully. Friends Count: $friendsCount, Are Friends: $areFriends, Trips: ${trips.length}");

    notifyListeners();
    return {
      ...data,
      'friendsCount': friendsCount,
      'friendsDetails': friendsDetails,
      'areFriends': areFriends,  // Add this to indicate friendship status
      'trips': trips,  // Include user's trips in profile data
    };
  } catch (e) {
    print("Error fetching profile: $e");
    throw Exception('Failed to fetch profile: ${e.toString()}');
  }
}



Future<List<Map<String, dynamic>>> fetchUserTrips({required String userId}) async {
  try {
    print("Fetching trips for user: $userId");

    // Get user document
    final userSnapshot = await _firestore.collection('users').doc(userId).get();

    if (!userSnapshot.exists || userSnapshot.data()?['trips'] == null) {
      print("No trips found for user: $userId.");
      return [];
    }

    List<String> tripIds = List<String>.from(userSnapshot.data()?['trips'] ?? []);
    print("Trip IDs found: $tripIds");

    if (tripIds.isEmpty) {
      return [];
    }

    // Fetch trip details from the 'trips' collection
    final tripSnapshot = await _firestore.collection('trips')
        .where(FieldPath.documentId, whereIn: tripIds)
        .get();

    List<Map<String, dynamic>> trips = tripSnapshot.docs.map((doc) => doc.data()).toList();

    print("Fetched ${trips.length} trips for user: $userId");

    return trips;
  } catch (e) {
    print("Error fetching user trips: $e");
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
    print("Error checking friendship: $e");
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

    return snapshot.size; // Returns the number of documents in the subcollection
  } catch (e) {
    print("Error counting friends: $e");
    return 0;
  }
}





Future<List<Map<String, dynamic>>> fetchFriendsDetails(String userId) async {
  List<Map<String, dynamic>> friendsDetails = [];

  try {
    final friendsSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .get();

    for (var doc in friendsSnapshot.docs) {
      final friendData = doc.data();
      final friendId = doc.id; // Assuming the document ID is the friend's userId

      // Fetch full profile of the friend
      final friendProfile = await _firestore.collection('users').doc(friendId).get();
      if (friendProfile.exists) {
        final friendInfo = friendProfile.data() as Map<String, dynamic>;
        friendsDetails.add({
          'userId' : friendId,
          'username': friendInfo['username'] ?? 'Unknown',
          'profileImage': friendInfo['profileImage'] ?? '', // Handle empty images
        });
      }
    }
  } catch (e) {
    print("Error fetching friend details: $e");
  }

  return friendsDetails;
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
      print('Error checking profile completion: ${e.toString()}');
      return false;
    }
  }

  // Helper method to validate date format
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
    if (user != null) {
      return user.email;
    }
    return null; // No user is logged in
  } catch (e) {
    print('Error fetching email: $e');
    return null;
  }
}

// Add this method to the existing ProfileProvider class

// Future<Map<String, dynamic>> fetchUserProfileById(String userId) async {
//   try {
//     final snapshot = await _firestore.collection('users').doc(userId).get();
    
//     if (!snapshot.exists) {
//       print("Profile not found for user: $userId");
//       return {};
//     }

//     final data = snapshot.data() as Map<String, dynamic>;
    
//     // Only return public data if the profile is not public
//     if (!(data['isPublic'] ?? false)) {
//       return {
//         'username': data['username'],
//         'profileImage': data['profileImage'],
//         'isPublic': false,
//       };
//     }

//     return data;
//   } catch (e) {
//     print("Error fetching profile by ID: $e");
//     throw Exception('Failed to fetch profile: ${e.toString()}');
//   }


// }
}