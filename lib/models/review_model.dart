import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String reviewId;
  final String placeName;
  final String text;
  final Timestamp timestamp;
  final List<Map<String, dynamic>> comments;
  final String userId;
  final String userName;
  final double rating;
  final int totalRatings;

  ReviewModel({
    required this.reviewId,
    required this.placeName,
    required this.text,
    required this.timestamp,
    required this.comments,
    required this.userId,
    required this.userName,
    required this.rating,
    required this.totalRatings,
  });

  factory ReviewModel.fromFirestore(Map<String, dynamic> data) {
    return ReviewModel(
      reviewId: data['reviewId'] ?? '',
      placeName: data['placeName'] ?? '',
      text: data['text'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      comments: List<Map<String, dynamic>>.from(data['comments'] ?? []),
      userId: data['userId'] ?? '',
      userName: data['userName'] ?? 'Anonymous',
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalRatings: data['totalRatings'] is int
          ? data['totalRatings']
          : int.tryParse(data['totalRatings'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'reviewId': reviewId,
      'placeName': placeName,
      'text': text,
      'timestamp': timestamp,
      'comments': comments,
      'userId': userId,
      'userName': userName,
      'rating': rating,
      'totalRatings': totalRatings,
    };
  }
}
