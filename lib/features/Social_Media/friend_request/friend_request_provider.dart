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

  List<FriendRequestModel> get pendingRequests => _pendingRequests;

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


         // Get the current user ID
    String? userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) {
      print("User not logged in.");
      return;
    }

    // Fetch pending requests for the current user
    _pendingRequests = await _friendRequestService.fetchPendingRequests(userId);
    notifyListeners(); // Notify listeners when data changes
  } catch (e) {
    print("Error fetching pending requests: $e");print("Error fetching pending requests: $e");
    }
  }

  // Accept a friend request
 Future<void> acceptFriendRequest(String senderId, String receiverId) async {
  try {
    await _friendRequestService.updateFriendRequestStatus(senderId, receiverId, 'accepted');
    // Refresh the list after accepting
    await fetchPendingRequests(receiverId);
  } catch (e) {
    print("Error accepting friend request: $e");
  }
}


  // Decline a friend request
  Future<void> declineFriendRequest(String senderId, String receiverId) async {
    try {
      await _friendRequestService.updateFriendRequestStatus(senderId, receiverId, 'declined');
      // Refresh the list after declining
      await fetchPendingRequests(receiverId);
    } catch (e) {
      print("Error declining friend request: $e");
    }
  }


  // **New: Unfriend a user**
  Future<void> unfriendUser(String currentUserId, String friendUserId) async {
    try {
      // Remove friend relationship for current user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .collection('friends')
          .doc(friendUserId)
          .delete();

      // Remove friend relationship for the other user
      await FirebaseFirestore.instance
          .collection('users')
          .doc(friendUserId)
          .collection('friends')
          .doc(currentUserId)
          .delete();

      notifyListeners();
    } catch (e) {
      print("Error unfriending user: $e");
      throw Exception("Failed to unfriend user: $e");
    }
  }

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
}
