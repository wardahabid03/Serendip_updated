import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/profile.dart/provider/profile_provider.dart';
import '../../models/review_model.dart';
import 'package:geocoding/geocoding.dart'; // Import geocoding

class ReviewProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<ReviewModel> _reviews = [];

  List<ReviewModel> get reviews => _reviews;

Future<void> fetchAllReviews() async {
  try {
    print("Fetching all reviews");
    
    final querySnapshot = await _firestore.collection('reviews').get();

    // ✅ Convert each document snapshot into ReviewModel correctly
    _reviews = querySnapshot.docs.map((doc) {
      final data = doc.data();  // ✅ Call `.data()` to extract the map
      return ReviewModel.fromFirestore(data); 
    }).toList();

    print("Fetched ${_reviews.length} reviews successfully!");
    
    notifyListeners();
  } catch (e) {
    print("Error fetching reviews: $e");
  }
}

Future<void> addReview(String reviewId, String placeName, String text, BuildContext context) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print("No user signed in");
    return;
  }
  print("Adding review for User ID: ${user.uid}");

  try {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    String userName = await profileProvider.getUsernameById(user.uid);
    print("Fetched username: $userName");

    final newReview = ReviewModel(
      reviewId: reviewId,  
      placeName: placeName,
      text: text,
      timestamp: Timestamp.now(),
      comments: [],
      userId: user.uid,
      userName: userName,
    );

    await _firestore.collection('reviews').add(newReview.toFirestore());

    print("Review added successfully by $userName");

    // ✅ Fetch the updated list of reviews
    await fetchAllReviews();

    // ✅ Force UI update
    notifyListeners();
  } catch (e) {
    print("Error adding review: $e");
  }
}



Future<void> addComment(BuildContext context, String reviewId, String commentText) async {
  final reviewRef = _firestore.collection('reviews').where('reviewId', isEqualTo: reviewId);

  // Get the current user ID
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    print("No user signed in");
    return;
  }

  // Fetch the username from ProfileProvider using the userId
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
  String userName = await profileProvider.getUsernameById(user.uid);

  // Create the new comment
  final newComment = {
    'userName': userName,
    'text': commentText,
    'timestamp': Timestamp.now(),
  };

  // ✅ Fetch the document ID first
  QuerySnapshot snapshot = await reviewRef.get();
  if (snapshot.docs.isEmpty) {
    print("Review not found for ID: $reviewId");
    return;
  }
  String docId = snapshot.docs.first.id; // Get the actual Firestore document ID
  final docRef = _firestore.collection('reviews').doc(docId);

  // ✅ Update Firestore
  await docRef.update({
    'comments': FieldValue.arrayUnion([newComment])
  }).then((_) async {
    print("Comment added successfully");

    // ✅ Re-fetch all reviews from Firestore (to update UI)
    await fetchAllReviews();

    // ✅ Notify UI to rebuild
    notifyListeners();
  }).catchError((error) {
    print("Failed to add comment: $error");
  });
}



}
