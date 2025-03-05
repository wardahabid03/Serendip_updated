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
  File? _selectedImage;
  Map<String, dynamic>? _repliedMessage; // Stores the replied message details

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
      'repliedMessage': _repliedMessage, // Store replied message details
    });

    _messageController.clear();
    setState(() {
      _repliedMessage = null; // Clear reply preview after sending
    });
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
            Expanded(child: Image.file(_selectedImage!, fit: BoxFit.contain)),
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

  Widget _buildReplyPreview() {
    if (_repliedMessage == null) return SizedBox.shrink();

    return Container(
      padding: EdgeInsets.all(8),
      margin: EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _repliedMessage!['senderId'] == _auth.currentUser!.uid ? "You" : "Friend",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                _repliedMessage!['text'] != null
                    ? Text(_repliedMessage!['text'], maxLines: 1, overflow: TextOverflow.ellipsis)
                    : (_repliedMessage!['mediaUrl'] != null
                        ? Text("[Media]", style: TextStyle(fontStyle: FontStyle.italic))
                        : SizedBox.shrink()),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.close, size: 18),
            onPressed: () => setState(() => _repliedMessage = null),
          ),
        ],
      ),
    );
  }

  Widget _buildRepliedMessage(Map<String, dynamic> repliedMessage) {
    return Container(
      margin: EdgeInsets.only(bottom: 5),
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            repliedMessage['senderId'] == _auth.currentUser!.uid ? "You" : "Friend",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          repliedMessage['text'] != null
              ? Text(repliedMessage['text'])
              : (repliedMessage['mediaUrl'] != null ? Text("[Media]") : SizedBox.shrink()),
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
                    final repliedMessage = messageData['repliedMessage'];

                    return GestureDetector(
                      onLongPress: () {
                        setState(() {
                          _repliedMessage = {
                            'senderId': message['senderId'],
                            'text': message['text'],
                            'mediaUrl': message['mediaUrl'],
                            'mediaType': message['mediaType'],
                          };
                        });
                      },
                      child: Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            if (repliedMessage != null) _buildRepliedMessage(repliedMessage),
                            Container(
                              margin: EdgeInsets.symmetric(vertical: 5, horizontal: 10),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isMe ? tealColor : Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: mediaUrl != null
                                  ? Image.network(mediaUrl, width: 200, height: 200, fit: BoxFit.cover)
                                  : Text(text ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),













































            
          ),
          _buildReplyPreview(),
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
