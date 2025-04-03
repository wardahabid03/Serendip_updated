import 'package:cloud_firestore/cloud_firestore.dart';

class FriendRequestModel {
  final String fromUserId;
  final String toUserId;
  String status;
  String username;
  String profileImageUrl;
  DateTime? timestamp;

  FriendRequestModel({
    required this.fromUserId,
    required this.toUserId,
    required this.status,
    this.username = 'Unknown',
    this.profileImageUrl = '',
    this.timestamp,
  });

  // Factory method to create an instance from Firestore data
  factory FriendRequestModel.fromMap(Map<String, dynamic> data) {
    return FriendRequestModel(
      fromUserId: data['from_user'] ?? '',
      toUserId: data['to_user'] ?? '',
      status: data['status'] ?? 'pending',
      username: data['username'] ?? 'Unknown',
      profileImageUrl: data['profileImageUrl'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
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

  // ✅ Firestore data conversion methods for `withConverter`
  static FriendRequestModel fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> snapshot,
      SnapshotOptions? options) {
    final data = snapshot.data();
    if (data == null) {
      throw Exception("Friend request data is null");
    }
    return FriendRequestModel.fromMap(data);
  }

  static Map<String, dynamic> toFirestore(FriendRequestModel request, SetOptions? options) {
    return request.toMap();
  }
}
