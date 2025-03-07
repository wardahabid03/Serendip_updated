import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/core/routes.dart';
import 'package:serendip/features/chat.dart/chat_provider.dart';
import '../profile.dart/provider/profile_provider.dart';

class ContactsScreen extends StatefulWidget {
  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
      final chatProvider = Provider.of<ChatProvider>(context, listen: false);

      // Load cached friends first for instant UI
      profileProvider.fetchFriendsDetails(profileProvider.currentUserId);

      // Start listening for unread messages
      chatProvider.listenForUnreadMessages();
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileProvider = Provider.of<ProfileProvider>(context);

    return Scaffold(
      appBar: AppBar(title: Text('Chats')),
      body: profileProvider.friendsDetails.isEmpty
          ? Center(child: Text("No friends found"))
          : Consumer<ChatProvider>(
              builder: (context, chatProvider, _) {
                return ListView.separated(
                  itemCount: profileProvider.friendsDetails.length,
                  separatorBuilder: (context, index) => Divider(color: Colors.teal),
                  itemBuilder: (context, index) {
                    final friend = profileProvider.friendsDetails[index];
                    final chatRoomId = chatProvider.getChatRoomId(friend['userId']);
                    final unreadCount = chatProvider.getUnreadCount(chatRoomId);

                    final profileImage = friend['profileImage'];

                    print("👤 Checking friend: ${friend['username']} (${friend['userId']}), Unread: $unreadCount");

                    return ListTile(
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            radius: 25,
                            backgroundImage: profileImage != null && profileImage.isNotEmpty
                                ? NetworkImage(profileImage)
                                : AssetImage('assets/images/profile.png') as ImageProvider,
                          ),
                          if (unreadCount > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                constraints: BoxConstraints(minWidth: 20, minHeight: 20),
                                child: Center(
                                  child: Text(
                                    unreadCount.toString(),
                                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(friend['username'] ?? 'Unknown'),
                      subtitle: unreadCount > 0
                          ? Text("New messages", style: TextStyle(color: Colors.red))
                          : null,
                      onTap: () {
                        chatProvider.markMessagesAsSeen(friend['userId']);
                        Navigator.of(context).pushNamed(
                          AppRoutes.chat,
                          arguments: {
                            'userId': friend['userId'],
                            'username': friend['username'],
                            'profileImage': friend['profileImage'],
},
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }
}
