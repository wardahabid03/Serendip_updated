import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/review_model.dart';

class ReviewProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _showReviews = true;

  List<ReviewModel> _reviews = [];
  bool get showReviews => _showReviews;
  List<ReviewModel> get reviews => _reviews;

  void toggleShowReviews(bool value) {
    _showReviews = value;
    notifyListeners();
  }

  Future<void> fetchReviews(String placeId) async {
    final snapshot = await _firestore
        .collection('places')
        .doc(placeId)
        .collection('reviews')
        .orderBy('timestamp', descending: true)
        .get();

    _reviews = snapshot.docs.map((doc) => ReviewModel.fromFirestore(doc)).toList();
    notifyListeners();
  }

  Future<void> addReview(String placeId, String placeName, String text) async {
    final newReview = ReviewModel(
      reviewId: '',
      placeId: placeId,
      placeName: placeName,
      text: text,
      timestamp: Timestamp.now(),
      comments: [],
    );

    await _firestore
        .collection('places')
        .doc(placeId)
        .collection('reviews')
        .add(newReview.toFirestore());

    await fetchReviews(placeId);
  }

  Future<void> addComment(String placeId, String reviewId, String commentText) async {
    final reviewRef = _firestore.collection('places').doc(placeId).collection('reviews').doc(reviewId);

    await reviewRef.update({
      'comments': FieldValue.arrayUnion([
        {'text': commentText, 'timestamp': Timestamp.now()}
      ])
    });

    await fetchReviews(placeId);
  }
}
