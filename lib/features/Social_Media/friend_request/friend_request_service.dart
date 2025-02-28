import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../models/friend_request_model.dart';

class FriendRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Send a friend request
  Future<void> sendFriendRequest(String fromUserId, String toUserId) async {
    final friendRequest = FriendRequestModel(
      fromUserId: fromUserId,
      toUserId: toUserId,
      status: 'pending',
    );

    try {
      await _addFriendRequest(friendRequest);
    } catch (e) {
      throw Exception("Error sending friend request: $e");
    }
  }

  // Fetch pending friend requests (with user details from 'users' collection)
  Future<List<FriendRequestModel>> fetchPendingRequests(String userId) async {
    try {
      final querySnapshot = await _fetchFriendRequests(userId);

      List<FriendRequestModel> requests = [];
      for (var doc in querySnapshot.docs) {
        final fromUserId = doc['from_user'];

        // Fetch user data (username and profile image) from the 'users' collection
        final userData = await _fetchUserData(fromUserId);

        if (userData != null) {
        final friendRequest = FriendRequestModel.fromMap(doc.data() as Map<String, dynamic>);

          friendRequest.username = userData['username'];
          friendRequest.profileImageUrl = userData['profileImage'];

          requests.add(friendRequest);
        }
      }
      return requests;
    } catch (e) {
      throw Exception("Error fetching pending requests: $e");
    }
  }

  // Update friend request status (accept/decline)
  // Future<void> updateFriendRequestStatus(FriendRequestModel request, String status) async {
  //   try {
  //     await _updateFriendRequestStatus(request, status);
  //   } catch (e) {
  //     throw Exception("Error updating friend request status: $e");
  //   }
  // }

  // Firebase operations - Modularized

  // Add a friend request to Firestore
  Future<void> _addFriendRequest(FriendRequestModel friendRequest) async {
    await _firestore.collection('friend_requests').add(friendRequest.toMap());
  }

  // Fetch friend requests for a given user
  Future<QuerySnapshot> _fetchFriendRequests(String userId) async {
    return await _firestore
        .collection('friend_requests')
        .where('to_user', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
  }

  // Fetch user data from the 'users' collection
  Future<Map<String, dynamic>?> _fetchUserData(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      return userDoc.data();
    } catch (e) {
      print("Error fetching user data: $e");
      return null;
    }
  }

Future<void> updateFriendRequestStatus(String senderId, String receiverId, String status) async {
  try {
    final querySnapshot = await _firestore
        .collection('friend_requests')
        .where('from_user', isEqualTo: senderId)
        .where('to_user', isEqualTo: receiverId)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final docId = querySnapshot.docs.first.id;

      // Update request status
      await _firestore.collection('friend_requests').doc(docId).update({
        'status': status,
      });

      // If accepted, add users to each other's friends list
      if (status == 'accepted') {
        await _addToFriendsList(senderId, receiverId);
        await _addToFriendsList(receiverId, senderId);

        // Delete friend request after becoming friends
        await _firestore.collection('friend_requests').doc(docId).delete();
      }
    } else {
      throw Exception("Friend request not found.");
    }
  } catch (e) {
    throw Exception("Error updating friend request status: $e");
  }
}




Future<void> _addToFriendsList(String userId, String friendId) async {
  try {
    final friendRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('friends')
        .doc(friendId); // Friend's ID as document ID

    await friendRef.set({
      'friendId': friendId,
      'addedAt': FieldValue.serverTimestamp(), // Timestamp of friendship
    });
  } catch (e) {
    throw Exception("Error adding to friends list: $e");
  }
}

}
