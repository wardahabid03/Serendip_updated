class FriendRequestModel {
  final String fromUserId;
  final String toUserId;
  final String status;  // pending, accepted, declined

  FriendRequestModel({
    required this.fromUserId,
    required this.toUserId,
    required this.status,
  });

  factory FriendRequestModel.fromMap(Map<String, dynamic> data) {
    return FriendRequestModel(
      fromUserId: data['from_user'],
      toUserId: data['to_user'],
      status: data['status'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'from_user': fromUserId,
      'to_user': toUserId,
      'status': status,
    };
  }
}
