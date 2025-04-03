import 'package:cloud_firestore/cloud_firestore.dart';

class ReviewModel {
  final String reviewId;
  final String placeId;
  final String placeName;
  final String text;
  final Timestamp timestamp;
  final List<Map<String, dynamic>> comments; // List of comments

  ReviewModel({
    required this.reviewId,
    required this.placeId,
    required this.placeName,
    required this.text,
    required this.timestamp,
    required this.comments,
  });

  factory ReviewModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ReviewModel(
      reviewId: doc.id,
      placeId: data['placeId'],
      placeName: data['placeName'],
      text: data['text'],
      timestamp: data['timestamp'],
      comments: List<Map<String, dynamic>>.from(data['comments'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'placeId': placeId,
      'placeName': placeName,
      'text': text,
      'timestamp': timestamp,
      'comments': comments,
    };
  }
}
