import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String reviewId;
  final String placeName;
  final String text;
  final Timestamp timestamp;
  final List<Map<String, dynamic>> comments;
  final String userId;  // ✅ New field
  final String userName; // ✅ New field

  ReviewModel({
    required this.reviewId,
    required this.placeName,
    required this.text,
    required this.timestamp,
    required this.comments,
    required this.userId,
    required this.userName,
  });

  factory ReviewModel.fromFirestore(Map<String, dynamic> data) {
    return ReviewModel(
      reviewId: data['reviewId'],
      placeName: data['placeName'],
      text: data['text'],
      timestamp: data['timestamp'],
      comments: List<Map<String, dynamic>>.from(data['comments'] ?? []),
      userId: data['userId'] ?? "",  // ✅ Ensure it’s not null
      userName: data['userName'] ?? "Unknown",
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reviewId': reviewId,
      'placeName': placeName,
      'text': text,
      'timestamp': timestamp,
      'comments': comments,
      'userId': userId,  // ✅ Send userId to Firestore
      'userName': userName, // ✅ Send userName to Firestore
    };
  }
}
