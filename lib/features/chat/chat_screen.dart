import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'package:serendip/core/constant/colors.dart';
import 'chat_provider.dart';

class ChatScreen extends StatefulWidget {
  final String userId;
  final String username;
  final String profileImage;

  ChatScreen({required this.userId, required this.username,required this.profileImage});

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ValueNotifier<QueryDocumentSnapshot<Map<String, dynamic>>?> _replyingTo = ValueNotifier(null);

  @override
  void dispose() {
    _messageController.dispose();
    _replyingTo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context, listen: false);
    final chatRoomId = chatProvider.getChatRoomId(widget.userId);

    return Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading : false,
  title: Row(

    children: [
      // ✅ Profile Image
      CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey[300], // Placeholder color
        backgroundImage: widget.profileImage != '' && widget.profileImage!.isNotEmpty
            ? NetworkImage(widget.profileImage)
                                : const AssetImage('assets/images/profile.png') as ImageProvider,
     
      ),
      SizedBox(width: 10),

      // ✅ Username
      Expanded(
        child: Text(
          widget.username,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis, // Prevents text overflow
        ),
      ),
    ],
  ),
),

      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: FirebaseFirestore.instance
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
                    final messageDoc = messages[index] as QueryDocumentSnapshot<Map<String, dynamic>>;
                    final messageData = messageDoc.data();
                    final isMe = messageData['senderId'] == FirebaseAuth.instance.currentUser!.uid;
                    final text = messageData['text'] ?? '';
                    final mediaUrl = messageData['mediaUrl'];
                    final replyText = messageData.containsKey('replyText') ? messageData['replyText'] : null;

                    return GestureDetector(
                      onLongPress: () {
                        if (isMe) {
                          chatProvider.showDeleteConfirmation(context, chatRoomId, messageDoc);
                        }
                      },
                      onHorizontalDragEnd: (details) {
                        if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 100) {
                          _replyingTo.value = messageDoc; // ✅ Set message for reply (Only UI updates)
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
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (replyText != null)
                                Container(
                                  padding: EdgeInsets.all(6),
                                  margin: EdgeInsets.only(bottom: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[400],
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    replyText ?? '📷 Photo',
                                    style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.black),
                                  ),
                                ),
                              mediaUrl != null
                                  ? GestureDetector(
                                      onTap: () => chatProvider.openMediaViewer(context, mediaUrl, messages, index),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(mediaUrl, width: 200, height: 200, fit: BoxFit.cover),
                                      ),
                                    )
                                  : Text(
                                      text,
                                      style: TextStyle(color: isMe ? Colors.white : Colors.black),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

   ValueListenableBuilder<QueryDocumentSnapshot<Map<String, dynamic>>?>(
  valueListenable: _replyingTo,
  builder: (context, replyingTo, child) {
    if (replyingTo == null) return SizedBox(); // Hide if no reply
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      padding: EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(color: Colors.teal, width: 5), // Highlighted reply bar
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Ensure proper spacing
        children: [
          // ✅ Vertically Centered Text
          Expanded(
            child: Container(
              alignment: Alignment.centerLeft, // Center text vertically
              child: Text(
                replyingTo['text'] ?? '📷 Photo',
                style: TextStyle(fontSize: 14, color: Colors.black87),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),

          // ✅ Close Button
          IconButton(
            icon: Icon(Icons.close, color: Colors.red, size: 20),
            onPressed: () => _replyingTo.value = null,
          ),
        ],
      ),
    );
  },
),


          // 🔥 Message Input Field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      hintText: 'Type a message...',
                      filled: true,
                      fillColor: Colors.grey[200],
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: const BorderSide(color: tealColor, width: 2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
                        borderSide: BorderSide.none,
                      ),
                      prefixIcon: IconButton(
                        icon: Icon(Icons.attach_file, color: Colors.grey[600]),
                        onPressed: () => chatProvider.pickAndPreviewImage(context, chatRoomId, widget.userId),
                      ),
                      contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: Colors.teal,
                  radius: 25,
                  child: IconButton(
                    icon: Icon(Icons.send, color: Colors.white),
                    onPressed: () {
                      if (_messageController.text.trim().isEmpty) return;

                      chatProvider.sendMessage(
                        chatRoomId,
                        widget.userId,
                        _messageController.text,
                        replyText: _replyingTo.value != null ? _replyingTo.value!['text'] : null, // ✅ Send replyText if replying
                      );

                      _messageController.clear();
                      _replyingTo.value = null; // ✅ Clear reply without full rebuild
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
