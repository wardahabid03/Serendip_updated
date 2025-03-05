// import 'package:flutter/material.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';

// import '../../models/chat_model.dart';


// class ChatProvider extends ChangeNotifier {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth _auth = FirebaseAuth.instance;

//   Future<void> sendMessage(String receiverId, String message) async {
//     if (message.trim().isEmpty) return;

//     final String senderId = _auth.currentUser!.uid;

//     final ChatMessage chatMessage = ChatMessage(
//       senderId: senderId,
//       receiverId: receiverId,
//       message: message,
//       timestamp: Timestamp.now(),
//     );

//     await _firestore.collection('chats').add(chatMessage.toMap());
//   }

//   Stream<List<ChatMessage>> getMessages(String receiverId) {
//     final String senderId = _auth.currentUser!.uid;

//     return _firestore
//         .collection('chats')
//         .where('senderId', isEqualTo: senderId)
//         .where('receiverId', isEqualTo: receiverId)
//         .snapshots()
//         .map((snapshot) {
//       return snapshot.docs
//           .map((doc) => ChatMessage.fromMap(doc.data() as Map<String, dynamic>))
//           .toList();
//     });
//   }
// }


import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../models/chat_model.dart';

class ChatProvider extends ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> sendMessage(String receiverId, String message, {String? mediaUrl, String? mediaType}) async {
    if (message.trim().isEmpty && mediaUrl == null) return;

    final String senderId = _auth.currentUser!.uid;

    final ChatMessage chatMessage = ChatMessage(
      senderId: senderId,
      receiverId: receiverId,
      message: message,
      mediaUrl: mediaUrl,
      timestamp: Timestamp.now(),
    );

    await _firestore.collection('chats').add(chatMessage.toMap());
  }

  Stream<List<ChatMessage>> getMessages(String receiverId) {
    final String senderId = _auth.currentUser!.uid;

    return _firestore
        .collection('chats')
        .where('senderId', isEqualTo: senderId)
        .where('receiverId', isEqualTo: receiverId)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => ChatMessage.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<String?> uploadMedia(File file, String path) async {
    try {
      final ref = _storage.ref().child(path);
      await ref.putFile(file);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Error uploading media: $e");
      return null;
    }
  }

  Future<void> sendMediaMessage(String receiverId, XFile file) async {
    final String fileType = file.mimeType!.startsWith('video') ? 'video' : 'image';
    final File fileToUpload = File(file.path);
    final String? mediaUrl = await uploadMedia(fileToUpload, 'chat_media/${DateTime.now().millisecondsSinceEpoch}');
    if (mediaUrl != null) {
      await sendMessage(receiverId, '', mediaUrl: mediaUrl, mediaType: fileType);
    }
  }
}

