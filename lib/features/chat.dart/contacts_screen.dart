import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/core/routes.dart';
import 'package:serendip/features/profile.dart/provider/profile_provider.dart';

class ContactsScreen extends StatefulWidget {
  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  late ProfileProvider profileProvider;
  late Future<void> _loadFriendsFuture;

  @override
  void initState() {
    super.initState();
    profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    
    if (profileProvider.friendsDetails.isEmpty) {
      _loadFriendsFuture = profileProvider.fetchFriendsDetails(profileProvider.currentUserId);
    } else {
      _loadFriendsFuture = Future.value();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Chats')),
      body: FutureBuilder(
        future: _loadFriendsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && profileProvider.friendsDetails.isEmpty) {
            return Center(child: CircularProgressIndicator());
          }
          
          if (profileProvider.friendsDetails.isEmpty) {
            return Center(child: Text("No friends found"));
          }

          return ListView.builder(
            itemCount: profileProvider.friendsDetails.length,
            itemBuilder: (context, index) {
              final friend = profileProvider.friendsDetails[index];

              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: friend['profileImage'] != null && friend['profileImage'].isNotEmpty
                      ? NetworkImage(friend['profileImage'])
                      : AssetImage('assets/images/profile.png') as ImageProvider,
                ),
                title: Text(friend['username'] ?? 'Unknown'),
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.chat,
                    arguments: {
                      'userId': friend['userId'],
                      'username': friend['username'],
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
