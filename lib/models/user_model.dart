import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UserModel {
  final String userId;
  final String username;
  final String email;
  final String? profileImage;
  final String? dob;
  final String? bio;
  final bool isPublic;
  final bool locationEnabled;
  final List<String> friends;
  final List<String> trips; // 🆕 List of trip IDs
  final PrivacySettings privacySettings;
  final LatLng location;
  final bool isProfileComplete;
  final DateTime? updatedAt;
  final int tripCount;
  final int friendCount;
  final int photoCount;
  final bool isFriend;

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    this.profileImage,
    this.dob,
    this.bio,
    this.isPublic = true,
    this.locationEnabled = false,
    required this.friends,
    required this.trips, // 🆕 Initialize trips
    required this.privacySettings,
    required this.location,
    this.isProfileComplete = false,
    this.updatedAt,
    this.tripCount = 0,
    this.friendCount = 0,
    this.photoCount = 0,
    this.isFriend = false,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      userId: id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      profileImage: data['profileImage'],
      dob: data['dob'],
      bio: data['bio'],
      isPublic: data['isPublic'] ?? true,
      locationEnabled: data['locationEnabled'] ?? false,
      friends: List<String>.from(data['friends'] ?? []),
      trips: List<String>.from(data['trips'] ?? []), // 🆕 Extract trip IDs
      privacySettings: PrivacySettings.fromMap(data['privacy_settings'] ?? {
        'default_trip_privacy': 'public',
        'default_image_privacy': 'friends',
      }),
      location: data['location'] != null
          ? LatLng(
              data['location']['latitude'] ?? 0.0,
              data['location']['longitude'] ?? 0.0,
            )
          : const LatLng(0, 0),
      isProfileComplete: data['isProfileComplete'] ?? false,
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      tripCount: data['tripCount'] ?? 0,
      friendCount: data['friendCount'] ?? 0,
      photoCount: data['photoCount'] ?? 0,
      isFriend: data['isFriend'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'profileImage': profileImage,
      'dob': dob,
      'bio': bio,
      'isPublic': isPublic,
      'locationEnabled': locationEnabled,
      'friends': friends,
      'trips': trips, // 🆕 Save trip IDs
      'privacy_settings': privacySettings.toMap(),
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      'isProfileComplete': isProfileComplete,
      'updatedAt': FieldValue.serverTimestamp(),
      'tripCount': tripCount,
      'friendCount': friendCount,
      'photoCount': photoCount,
      'isFriend': isFriend,
    };
  }

  // Create a copy of UserModel with updated fields
  UserModel copyWith({
    String? username,
    String? email,
    String? profileImage,
    String? dob,
    String? bio,
    bool? isPublic,
    bool? locationEnabled,
    List<String>? friends,
    List<String>? trips, // 🆕 Allow copying with updated trip list
    PrivacySettings? privacySettings,
    LatLng? location,
    bool? isProfileComplete,
    DateTime? updatedAt,
    int? tripCount,
    int? friendCount,
    int? photoCount,
    bool? isFriend,
  }) {
    return UserModel(
      userId: this.userId,
      username: username ?? this.username,
      email: email ?? this.email,
      profileImage: profileImage ?? this.profileImage,
      dob: dob ?? this.dob,
      bio: bio ?? this.bio,
      isPublic: isPublic ?? this.isPublic,
      locationEnabled: locationEnabled ?? this.locationEnabled,
      friends: friends ?? this.friends,
      trips: trips ?? this.trips, // 🆕 Maintain trip list
      privacySettings: privacySettings ?? this.privacySettings,
      location: location ?? this.location,
      isProfileComplete: isProfileComplete ?? this.isProfileComplete,
      updatedAt: updatedAt ?? this.updatedAt,
      tripCount: tripCount ?? this.tripCount,
      friendCount: friendCount ?? this.friendCount,
      photoCount: photoCount ?? this.photoCount,
      isFriend: isFriend ?? this.isFriend,
    );
  }
}


class PrivacySettings {
  final String defaultTripPrivacy; // public, friends, only_me
  final String defaultImagePrivacy; // public, friends, only_me

  PrivacySettings({
    required this.defaultTripPrivacy,
    required this.defaultImagePrivacy,
  });

  factory PrivacySettings.fromMap(Map<String, dynamic> data) {
    return PrivacySettings(
      defaultTripPrivacy: data['default_trip_privacy'] ?? 'public',
      defaultImagePrivacy: data['default_image_privacy'] ?? 'friends',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'default_trip_privacy': defaultTripPrivacy,
      'default_image_privacy': defaultImagePrivacy,
    };
  }

  // Create a copy of PrivacySettings with updated fields
  PrivacySettings copyWith({
    String? defaultTripPrivacy,
    String? defaultImagePrivacy,
  }) {
    return PrivacySettings(
      defaultTripPrivacy: defaultTripPrivacy ?? this.defaultTripPrivacy,
      defaultImagePrivacy: defaultImagePrivacy ?? this.defaultImagePrivacy,
    );
  }
}
