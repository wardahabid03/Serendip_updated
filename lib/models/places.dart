class Place {
  final String name;
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String category1;
  final String category2;
  final String category3;

  Place({
    required this.name,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.category1,
    required this.category2,
    required this.category3,
  });

  // A method to convert JSON response to a Place object
  factory Place.fromJson(Map<String, dynamic> json) {
    return Place(
      name: json['ll_key'],
      description: json['Desc'],
      imageUrl: json['imageurl'],
      latitude: json['latitude'],
      longitude: json['longitude'],
      category1: json['category 1'] ?? '', // Use empty string as fallback if category is not present
      category2: json['category 2'] ?? '', // Same for category 2
      category3: json['category 3'] ?? '', // Same for category 3
    );
  }
}
