class ImageModel {
  final String imageUrl;
  final DateTime uploadDate;
  final LocationModel location;
  final String privacy;  // public, friends, only_me

  ImageModel({
    required this.imageUrl,
    required this.uploadDate,
    required this.location,
    required this.privacy,
  });

  factory ImageModel.fromMap(Map<String, dynamic> data) {
    if (data['url'] == null || data['url'] is! String) {
      throw Exception('Missing or invalid image_url: ${data['url']}');
    }
    if (data['upload_date'] == null || data['upload_date'] is! String) {
      throw Exception('Missing or invalid upload_date: ${data['upload_date']}');
    }
    if (data['location'] == null) {
      throw Exception('Missing location data: ${data['location']}');
    }
    if (data['privacy'] == null || data['privacy'] is! String) {
      throw Exception('Missing or invalid privacy setting: ${data['privacy']}');
    }

    return ImageModel(
      imageUrl: data['url'],
      uploadDate: DateTime.parse(data['upload_date']),
      location: LocationModel.fromMap(data['location']),
      privacy: data['privacy'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'url': imageUrl,
      'upload_date': uploadDate.toIso8601String(),
      'location': location.toMap(),
      'privacy': privacy,
    };
  }
}

class LocationModel {
  final double latitude;
  final double longitude;

  LocationModel({
    required this.latitude,
    required this.longitude,
  });

  factory LocationModel.fromMap(Map<String, dynamic> data) {
    if (data['latitude'] == null || data['longitude'] == null) {
      throw Exception('Missing latitude or longitude in location data: $data');
    }
    if (data['latitude'] is! num || data['longitude'] is! num) {
      throw Exception('Latitude and longitude must be numbers: $data');
    }

    return LocationModel(
      latitude: data['latitude'].toDouble(),
      longitude: data['longitude'].toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}
