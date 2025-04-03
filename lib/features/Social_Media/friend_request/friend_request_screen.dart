import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:serendip/core/constant/colors.dart';
import 'package:serendip/features/Social_Media/friend_request/friend_request_provider.dart';

class FriendRequestPage extends StatefulWidget {
  @override
  _FriendRequestPageState createState() => _FriendRequestPageState();
}

class _FriendRequestPageState extends State<FriendRequestPage> {
  final String userId = FirebaseAuth.instance.currentUser?.uid ?? "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(fontSize: 22),
        ),
        backgroundColor: tealColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<FriendRequestProvider>(
        builder: (context, provider, child) {
          return FutureBuilder(
            future: provider.fetchPendingRequests(userId),
            builder: (context, snapshot) {
              if (provider.pendingRequests.isEmpty) {
                return const Center(
                  child: Text(
                    'No new notifications',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                );
              }

              Map<String, List<dynamic>> groupedRequests = {};
              for (var request in provider.pendingRequests) {
                String dateKey = _getDateKey(request.timestamp!);
                groupedRequests.putIfAbsent(dateKey, () => []).add(request);
              }

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: ListView(
                  children: groupedRequests.entries.map((entry) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10.0),
                          child: Text(
                            entry.key,
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        ...entry.value.map((request) => _buildRequestCard(request, provider)).toList(),
                      ],
                    );
                  }).toList(),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(dynamic request, FriendRequestProvider provider) {
    return InkWell(
      onTap: () => Navigator.pushNamed(
        context,
        '/view_profile',
        arguments: request.fromUserId,
      ),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: ListTile(
            leading: CircleAvatar(
              radius: 30,
              backgroundImage: request.profileImageUrl != null
                  ? NetworkImage(request.profileImageUrl!)
                  : const AssetImage('assets/images/profile.png') as ImageProvider,
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black, fontSize: 16),
                    children: [
                      TextSpan(
                        text: "${request.username} ",
                        style: const TextStyle(fontWeight: FontWeight.bold, color: tealColor),
                      ),
                      const TextSpan(text: "sent you a friend request!"),
                    ],
                  ),
                ),
                if (request.status == 'pending')
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await provider.acceptFriendRequest(request.fromUserId, request.toUserId);
                            },
                            icon: const Icon(Icons.check, color: Colors.white),
                            label: const Text('Accept', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              await provider.declineFriendRequest(request.fromUserId, request.toUserId);
                            },
                            icon: const Icon(Icons.close, color: Colors.white),
                            label: const Text('Decline', style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDateKey(DateTime timestamp) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime requestDate = DateTime(timestamp.year, timestamp.month, timestamp.day);

    if (requestDate == today) {
      return "Today";
    } else if (requestDate == today.subtract(const Duration(days: 1))) {
      return "Yesterday";
    } else {
      return DateFormat('MMMM d, yyyy').format(requestDate);
    }
  }
}
