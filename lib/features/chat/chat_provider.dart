import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ChatProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();

  File? _selectedImage;
  File? get selectedImage => _selectedImage;

  Map<String, int> _unreadCounts = {};
  Map<String, StreamSubscription<QuerySnapshot>> _unreadListeners = {};

  Map<String, int> get unreadCounts => _unreadCounts;

  String getChatRoomId(String userId) {
    final currentUserId = _auth.currentUser!.uid;
    return currentUserId.hashCode <= userId.hashCode
        ? '$currentUserId-$userId'
        : '$userId-$currentUserId';
  }

  int getUnreadCount(String chatRoomId) {
    return _unreadCounts[chatRoomId] ?? 0;
  }

void sendMessage(String chatRoomId, String receiverId, String? text,
    {String? mediaUrl, String? mediaType, String? replyText}) {
  if (text?.trim().isEmpty == true && mediaUrl == null) {
    print("Message sending skipped: Empty text and no media.");
    return;
  }

  final currentUserId = _auth.currentUser!.uid;
  print("📤 Sending message to chatRoomId: $chatRoomId");

  // ✅ Ensure the chat room document exists
  _firestore.collection('chats').doc(chatRoomId).set({
    'users': [currentUserId, receiverId], // Save the users involved
    'lastMessage': mediaUrl == null ? text : "Sent a media",
    'lastMessageTime': FieldValue.serverTimestamp(),
  }, SetOptions(merge: true)).then((_) {
    print("✅ Chat room $chatRoomId created or updated.");
  }).catchError((e) {
    print("❌ Error creating chat room: $e");
  });

  // ✅ Add the message inside the chat room
  _firestore.collection('chats').doc(chatRoomId).collection('messages').add({
    'senderId': currentUserId,
    'receiverId': receiverId,
    'text': mediaUrl == null ? text : null,
    'mediaUrl': mediaUrl,
    'mediaType': mediaType,
    'replyText': replyText,
    'seen': false,
    'timestamp': FieldValue.serverTimestamp(),
  }).then((_) {
    print("✅ Message sent successfully.");
  }).catchError((e) {
    print("❌ Error sending message: $e");
  });
}



  Future<void> pickAndPreviewImage(
      BuildContext context, String chatRoomId, String receiverId) async {
    print("Opening gallery for image selection...");
    final XFile? pickedFile =
        await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) {
      print("Image selection cancelled.");
      return;
    }

    _selectedImage = File(pickedFile.path);
    notifyListeners();
    print("Image selected: ${_selectedImage!.path}");

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(child: Image.file(_selectedImage!, fit: BoxFit.contain)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(Icons.cancel, color: Colors.red, size: 30),
                  onPressed: () {
                    print("Image selection cancelled.");
                    _selectedImage = null;
                    notifyListeners();
                    Navigator.pop(context);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.green, size: 30),
                  onPressed: () {
                    print("Uploading image...");
                    uploadAndSendImage(chatRoomId, receiverId);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> uploadAndSendImage(String chatRoomId, String receiverId) async {
    if (_selectedImage == null) {
      print("No image selected for upload.");
      return;
    }

    String fileName =
        'chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg';
    try {
      TaskSnapshot snapshot = await FirebaseStorage.instance
          .ref(fileName)
          .putFile(_selectedImage!);
      String downloadUrl = await snapshot.ref.getDownloadURL();
      print("Image uploaded successfully: $downloadUrl");
      sendMessage(chatRoomId, receiverId, null,
          mediaUrl: downloadUrl, mediaType: 'image');
      _selectedImage = null;
      notifyListeners();
    } catch (e) {
      print("Image upload failed: $e");
    }
  }

void listenForUnreadMessages() {
  final currentUserId = _auth.currentUser?.uid;

  if (currentUserId == null) {
    print("❌ ERROR: No authenticated user found.");
    return;
    
  }

  print("✅ Listening for unread messages for user: $currentUserId");

  _firestore.collection('chats').get().then((chatDocs) {
    print("📁 Found ${chatDocs.docs.length} chat rooms.");

    for (var chatDoc in chatDocs.docs) {
      final chatRoomId = chatDoc.id;
      print("🔍 Checking chat room: $chatRoomId");

      if (_unreadListeners.containsKey(chatRoomId)) {
        print("⚠️ Listener already exists for $chatRoomId, skipping...");
        continue; // Prevent multiple listeners on the same chat room
      }

      print("👂 Setting up listener for unread messages in $chatRoomId...");

      _unreadListeners[chatRoomId] = _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .where('receiverId', isEqualTo: currentUserId)
          .where('seen', isEqualTo: false)
          .snapshots()
          .listen((messageSnapshot) {
        print(
            "📨 New unread messages fetched for $chatRoomId: ${messageSnapshot.docs.length}");

        for (var doc in messageSnapshot.docs) {
          print("📩 Unread Message: ${doc.data()}");
        }

        _unreadCounts[chatRoomId] = messageSnapshot.docs.length;

        print("🔔 Updated unread count for $chatRoomId: ${_unreadCounts[chatRoomId]}");

        notifyListeners();
      }, onError: (error) {
        print("❌ ERROR: Failed to listen to messages in $chatRoomId - $error");
      });
    }
  }).catchError((error) {
    print("❌ ERROR: Failed to fetch chat rooms - $error");
  });



  
}


  Future<void> markMessagesAsSeen(String friendId) async {
    final chatRoomId = getChatRoomId(friendId);
    print("Marking messages as seen in chatRoomId: $chatRoomId");

    final messages = await _firestore
        .collection('chats')
        .doc(chatRoomId)
        .collection('messages')
        .where('receiverId', isEqualTo: _auth.currentUser!.uid)
        .where('seen', isEqualTo: false)
        .get();

    for (var msg in messages.docs) {
      await msg.reference.update({'seen': true});
    }
    _unreadCounts[chatRoomId] = 0;
    notifyListeners();
    print("Unread messages updated for");
  }

  Future<void> deleteMessage(String chatRoomId, DocumentSnapshot message) async {
    try {
      if (message['mediaUrl'] != null) {
        await FirebaseStorage.instance.refFromURL(message['mediaUrl']).delete();
        print("Deleted media from storage.");
      }
      await _firestore
          .collection('chats')
          .doc(chatRoomId)
          .collection('messages')
          .doc(message.id)
          .delete();
      print("Message deleted successfully.");
    } catch (e) {
      print("Error deleting message: $e");
    }
  }

  void showDeleteConfirmation(
      BuildContext context, String chatRoomId, DocumentSnapshot message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Message"),
        content: Text("Are you sure you want to delete this message?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: Text("Cancel")),
          TextButton(
              onPressed: () {
                deleteMessage(chatRoomId, message);
                Navigator.pop(context);
              },
              child: Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void openMediaViewer(BuildContext context, String mediaUrl,
      List<QueryDocumentSnapshot> messages, int initialIndex) {
    List<String> imageUrls = messages
        .where((msg) => msg['mediaUrl'] != null && msg['mediaType'] == 'image')
        .map((msg) => msg['mediaUrl'] as String)
        .toList();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: PageView.builder(
          itemCount: imageUrls.length,
          controller: PageController(initialPage: initialIndex),
          itemBuilder: (context, index) {
            return GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                color: Colors.black,
                child: InteractiveViewer(
                  minScale: 1.0,
                  maxScale: 4.0,
                  child: Image.network(
                    imageUrls[index],
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
