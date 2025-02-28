import 'package:cloud_firestore/cloud_firestore.dart';

class FriendRequestModel {
  final String fromUserId;
  final String toUserId;
  String status;
  String? username;
  String? profileImageUrl;
  DateTime? timestamp; // Nullable DateTime

  FriendRequestModel({
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    this.username,
    this.profileImageUrl,
    this.timestamp,
  });

  // Factory method to create an instance from Firestore data
  factory FriendRequestModel.fromMap(Map<String, dynamic> data) {
    return FriendRequestModel(
      fromUserId: data['from_user'],
      toUserId: data['to_user'],
      status: data['status'],
      username: data['username'],
      profileImageUrl: data['profileImageUrl'],
      timestamp: data['timestamp'] != null
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.now(), // Default to current time if null
    );
  }

  // Method to convert the instance back to a map (for Firestore)
  Map<String, dynamic> toMap() {
    return {
      'from_user': fromUserId,
      'to_user': toUserId,
      'status': status,
      'username': username,
      'profileImageUrl': profileImageUrl,
      'timestamp': timestamp != null ? Timestamp.fromDate(timestamp!) : FieldValue.serverTimestamp(),
    };
  }
}
