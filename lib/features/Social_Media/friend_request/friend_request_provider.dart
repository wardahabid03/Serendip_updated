import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../models/friend_request_model.dart';
import 'friend_request_service.dart';


class FriendRequestProvider with ChangeNotifier {
  final FriendRequestService _friendRequestService = FriendRequestService();
  List<FriendRequestModel> _pendingRequests = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  StreamSubscription? _friendRequestsSubscription;

  List<FriendRequestModel> get pendingRequests => _pendingRequests;

  FriendRequestProvider() {
    _listenForUnseenRequests();
  }

  // Send a friend request
  Future<void> sendFriendRequest(String fromUserId, String toUserId) async {
    try {
      await _friendRequestService.sendFriendRequest(fromUserId, toUserId);
      // Refresh the list after sending
      await fetchPendingRequests(toUserId);
    } catch (e) {
      print("Error sending friend request: $e");
    }
  }

  // Fetch pending friend requests
  Future<void> fetchPendingRequests(String userId) async {
    try {
      String? currentUserId = _auth.currentUser?.uid;
      if (currentUserId == null) {
        print("User not logged in.");
        return;
      }

      _pendingRequests = await _friendRequestService.fetchPendingRequests(currentUserId);
      notifyListeners();
    } catch (e) {
      print("Error fetching pending requests: $e");
    }
  }

  // Listen for unseen friend requests
  void _listenForUnseenRequests() {
    String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

_friendRequestsSubscription = _firestore
    .collection('friend_requests')
    .where('to_user', isEqualTo: currentUserId)
    .where('status', isEqualTo: 'pending') // Only listen for new requests
    .snapshots()
    .listen((snapshot) {
  _pendingRequests = snapshot.docs
      .map((doc) => FriendRequestModel.fromFirestore(doc, null)) // ✅ Fix: Pass null
      .toList();
  notifyListeners();

// Notify UI to update
    }, onError: (error) {
      print("Error listening for friend requests: $error");
    });
  }

  // Accept a friend request
  Future<void> acceptFriendRequest(String senderId, String receiverId) async {
    try {
      await _friendRequestService.updateFriendRequestStatus(senderId, receiverId, 'accepted');
      await fetchPendingRequests(receiverId);
    } catch (e) {
      print("Error accepting friend request: $e");
    }
  }

  // Decline a friend request
  Future<void> declineFriendRequest(String senderId, String receiverId) async {
    try {
      await _friendRequestService.updateFriendRequestStatus(senderId, receiverId, 'declined');
      await fetchPendingRequests(receiverId);
    } catch (e) {
      print("Error declining friend request: $e");
    }
  }

  // Unfriend a user
  Future<void> unfriendUser(String currentUserId, String friendUserId) async {
    try {
      await _firestore.collection('users').doc(currentUserId).collection('friends').doc(friendUserId).delete();
      await _firestore.collection('users').doc(friendUserId).collection('friends').doc(currentUserId).delete();
      notifyListeners();
    } catch (e) {
      print("Error unfriending user: $e");
      throw Exception("Failed to unfriend user: $e");
    }
  }

  // Get friend request status
  Future<String> getFriendRequestStatus(String otherUserId) async {
    String? currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return 'none';

    try {
      final requestSnapshot = await _firestore
          .collection('friend_requests')
          .where('from_user', isEqualTo: currentUserId)
          .where('to_user', isEqualTo: otherUserId)
          .get();

      if (requestSnapshot.docs.isNotEmpty) {
        return 'sent';
      }

      final receivedSnapshot = await _firestore
          .collection('friend_requests')
          .where('from_user', isEqualTo: otherUserId)
          .where('to_user', isEqualTo: currentUserId)
          .get();

      if (receivedSnapshot.docs.isNotEmpty) {
        return 'received';
      }

      final friendsSnapshot = await _firestore
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(otherUserId)
          .get();

      if (friendsSnapshot.exists) {
        return 'friends';
      }

      return 'none';
    } catch (e) {
      print("Error checking friend request status: $e");
      return 'none';
    }
  }

  // Dispose listener when provider is removed
  @override
  void dispose() {
    _friendRequestsSubscription?.cancel();
    super.dispose();
  }
}
