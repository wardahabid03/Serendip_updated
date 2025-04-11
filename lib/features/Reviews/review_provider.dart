import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/profile.dart/provider/profile_provider.dart';
import '../../models/review_model.dart';

class ReviewProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<ReviewModel> _reviews = [];
  bool _showReviews = true;

  List<ReviewModel> get reviews => _reviews;
  bool get showReviews => _showReviews;

  void toggleReviews(bool value) {
    _showReviews = value;
    notifyListeners();
  }

  Future<void> fetchAllReviews() async {
    try {
      print("Fetching all reviews");

      final querySnapshot = await _firestore.collection('reviews').get();

      _reviews = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return ReviewModel.fromFirestore(data);
      }).toList();

      print("Fetched ${_reviews.length} reviews successfully!");
      notifyListeners();
    } catch (e) {
      print("Error fetching reviews: $e");
    }
  }

  Future<void> addReview(String reviewId, String placeName, String text, double rating, BuildContext context) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No user signed in");
      return;
    }

    try {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      String userName = await profileProvider.getUsernameById(user.uid) ?? 'Anonymous';

      final newReview = ReviewModel(
        reviewId: reviewId,
        placeName: placeName,
        text: text,
        timestamp: Timestamp.now(),
        comments: [],
        userId: user.uid,
        userName: userName,
        rating: rating,
        totalRatings: 1,
      );

      await _firestore.collection('reviews').add(newReview.toFirestore());
      print("Review added successfully by $userName");

      await fetchAllReviews();
    } catch (e) {
      print("Error adding review: $e");
    }
  }

  Future<void> addComment(
    BuildContext context,
    String reviewId,
    String commentText,
    double userRating,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("No user signed in");
      return;
    }

    try {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      String userName = await profileProvider.getUsernameById(user.uid) ?? 'Anonymous';

      final reviewQuery = await _firestore
          .collection('reviews')
          .where('reviewId', isEqualTo: reviewId)
          .get();

      if (reviewQuery.docs.isEmpty) {
        print("Review not found for ID: $reviewId");
        return;
      }

      final docSnapshot = reviewQuery.docs.first;
      final docRef = _firestore.collection('reviews').doc(docSnapshot.id);

      final existingData = docSnapshot.data();
      final currentRating = (existingData['rating'] ?? 0).toDouble();
      final totalRatings = (existingData['totalRatings'] ?? 0).toInt();

      final newTotalRatings = totalRatings + 1;
      final newAvgRating = ((currentRating * totalRatings) + userRating) / newTotalRatings;

      final newComment = {
        'userId': user.uid,
        'userName': userName,
        'text': commentText,
        'timestamp': Timestamp.now(),
      };

      await docRef.update({
        'comments': FieldValue.arrayUnion([newComment]),
        'rating': newAvgRating,
        'totalRatings': newTotalRatings,
      });

      print("Comment & rating added successfully");
      await fetchAllReviews();
    } catch (e) {
      print("Error adding comment: $e");
    }
  }
}