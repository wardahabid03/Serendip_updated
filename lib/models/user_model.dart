class UserModel {
  final String userId;
  final String username;
  final String email;
  final List<String> friends;  // List of user IDs
  final PrivacySettings privacySettings;

  UserModel({
    required this.userId,
    required this.username,
    required this.email,
    required this.friends,
    required this.privacySettings,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String id) {
    return UserModel(
      userId: id,
      username: data['username'],
      email: data['email'],
      friends: List<String>.from(data['friends'] ?? []),
      privacySettings: PrivacySettings.fromMap(data['privacy_settings']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'friends': friends,
      'privacy_settings': privacySettings.toMap(),
    };
  }
}

class PrivacySettings {
  final String defaultTripPrivacy;  // public, friends, only_me
  final String defaultImagePrivacy;  // public, friends, only_me

  PrivacySettings({
    required this.defaultTripPrivacy,
    required this.defaultImagePrivacy,
  });

  factory PrivacySettings.fromMap(Map<String, dynamic> data) {
    return PrivacySettings(
      defaultTripPrivacy: data['default_trip_privacy'],
      defaultImagePrivacy: data['default_image_privacy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'default_trip_privacy': defaultTripPrivacy,
      'default_image_privacy': defaultImagePrivacy,
    };
  }
}
