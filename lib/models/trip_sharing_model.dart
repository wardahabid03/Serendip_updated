class TripSharingModel {
  final String tripId;
  final String ownerId;
  final List<String> sharedWith;  // List of user IDs
  final DateTime sharedAt;

  TripSharingModel({
    required this.tripId,
    required this.ownerId,
    required this.sharedWith,
    required this.sharedAt,
  });

  factory TripSharingModel.fromMap(Map<String, dynamic> data) {
    return TripSharingModel(
      tripId: data['trip_id'],
      ownerId: data['owner_id'],
      sharedWith: List<String>.from(data['shared_with'] ?? []),
      sharedAt: DateTime.parse(data['shared_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'trip_id': tripId,
      'owner_id': ownerId,
      'shared_with': sharedWith,
      'shared_at': sharedAt.toIso8601String(),
    };
  }
}
