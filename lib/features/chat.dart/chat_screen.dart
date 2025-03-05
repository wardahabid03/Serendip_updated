import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:serendip/core/constant/colors.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String username;

  ChatScreen({required this.userId, required this.username});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage; // Stores selected image before sending

  String get chatRoomId {
    final currentUserId = _auth.currentUser!.uid;
    return currentUserId.hashCode <= widget.userId.hashCode
        ? '$currentUserId-${widget.userId}'
        : '${widget.userId}-$currentUserId';
  }

  void sendMessage({String? mediaUrl, String? mediaType}) {
    if (_messageController.text.trim().isEmpty && mediaUrl == null) return;

    _firestore.collection('chats').doc(chatRoomId).collection('messages').add({
      'senderId': _auth.currentUser!.uid,
      'receiverId': widget.userId,
      'text': mediaUrl == null ? _messageController.text : null,
      'mediaUrl': mediaUrl,
      'mediaType': mediaType,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();
  }

  Future<void> pickAndPreviewImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) return;

    setState(() {
      _selectedImage = File(pickedFile.path);
    });

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: Image.file(
                _selectedImage!,
                fit: BoxFit.contain,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                IconButton(
                  icon: Icon(Icons.cancel, color: Colors.red, size: 30),
                  onPressed: () {
                    setState(() => _selectedImage = null);
                    Navigator.pop(context);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.send, color: Colors.green, size: 30),
                  onPressed: () {
                    uploadAndSendImage();
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

  Future<void> uploadAndSendImage() async {
    if (_selectedImage == null) return;

    String fileName = 'chat_images/${DateTime.now().millisecondsSinceEpoch}.jpg';

    try {
      TaskSnapshot snapshot = await FirebaseStorage.instance.ref(fileName).putFile(_selectedImage!);
      String downloadUrl = await snapshot.ref.getDownloadURL();
      sendMessage(mediaUrl: downloadUrl, mediaType: 'image');
      setState(() => _selectedImage = null);
    } catch (e) {
      print("Image upload failed: $e");
    }
  }

  void openMediaViewer(String mediaUrl, String mediaType) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.black,
            child: InteractiveViewer(
              panEnabled: true,
              boundaryMargin: EdgeInsets.all(0),
              minScale: 1.0,
              maxScale: 4.0,
              child: Image.network(
                mediaUrl,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> deleteMessage(DocumentSnapshot message) async {
    try {
      if (message['mediaUrl'] != null) {
        await FirebaseStorage.instance.refFromURL(message['mediaUrl']).delete();
      }

      await _firestore.collection('chats').doc(chatRoomId).collection('messages').doc(message.id).delete();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Message deleted"),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      print("Error deleting message: $e");
    }
  }

  void showDeleteConfirmation(DocumentSnapshot message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Message"),
        content: Text("Are you sure you want to delete this message?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              deleteMessage(message);
              Navigator.pop(context);
            },
            child: Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.username)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _firestore
                  .collection('chats')
                  .doc(chatRoomId)
                  .collection('messages')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(child: Text('No messages yet.'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message['senderId'] == _auth.currentUser!.uid;

                    final messageData = message.data() as Map<String, dynamic>;
                    final text = messageData['text'];
                    final mediaUrl = messageData['mediaUrl'];
                    final mediaType = messageData['mediaType'];

                    return GestureDetector(
                      onLongPress: () {
                        if (isMe) {
                          showDeleteConfirmation(message);
                        }
                      },
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isMe ? tealColor : Colors.grey[300],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: mediaUrl != null
                              ? GestureDetector(
                                  onTap: () => openMediaViewer(mediaUrl, mediaType!),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(mediaUrl, width: 200, height: 200, fit: BoxFit.cover),
                                  ),
                                )
                              : Text(text ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black)),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(icon: Icon(Icons.attach_file), onPressed: pickAndPreviewImage),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(border: OutlineInputBorder(), hintText: 'Type a message...'),
                  ),
                ),
                IconButton(icon: Icon(Icons.send), onPressed: sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
