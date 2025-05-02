import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:geoflutterfire_plus/geoflutterfire_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:serendip/core/constant/colors.dart';
import 'package:serendip/core/routes.dart';
import 'package:serendip/core/utils/navigator_key.dart';
import 'package:serendip/features/Trip_Tracking/provider/trip_provider.dart';

class LocationService {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref("user_locations");
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  // To track recently notified memories
final Set<String> _recentMemoryIds = {};
final Map<String, DateTime> _memoryTimestamps = {};
final Duration _memoryCooldown = Duration(minutes: 10); // 10 minutes cooldown


  // Request location permission
  Future<bool> requestLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  // Get user location
  Future<LatLng?> getUserLocation() async {
    bool permissionGranted = await requestLocationPermission();
    if (!permissionGranted) return null;

    Position position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    return LatLng(position.latitude, position.longitude);
  }

  // Update user location in Firebase
  Future<void> updateUserLocation(LatLng location) async {
    String? uid = currentUserId;
    if (uid != null) {
      await _dbRef.child(uid).set({
        "latitude": location.latitude,
        "longitude": location.longitude,
        "timestamp": DateTime.now().millisecondsSinceEpoch,
      });
    }
  }



void checkForRevisitedLocations(LatLng currentLocation) {
  final center = GeoFirePoint(GeoPoint(currentLocation.latitude, currentLocation.longitude));
  final collectionRef = FirebaseFirestore.instance.collection('visited_points');

  final stream = GeoCollectionReference(collectionRef).subscribeWithin(
    center: center,
    radiusInKm: 1,
    field: 'geo',
    geopointFrom: (snapshot) => snapshot['geo']['geopoint'],
    queryBuilder: (query) => query.where('userId', isEqualTo: currentUserId),
  );

  stream.listen((List<DocumentSnapshot> documentList) {
    if (documentList.isNotEmpty) {
      final memoryDoc = documentList.first;
      final memoryId = memoryDoc.id;

      final lastShown = _memoryTimestamps[memoryId];
      final now = DateTime.now();

      if (lastShown == null || now.difference(lastShown) > _memoryCooldown) {
        _recentMemoryIds.add(memoryId);
        _memoryTimestamps[memoryId] = now;
        showMemoryNotification(memoryDoc);
      } else {
        print('Memory already shown recently. Skipping.');
      }
    }
  });
}

void showMemoryNotification(DocumentSnapshot memoryPoint) async {
  final data = memoryPoint.data() as Map<String, dynamic>;
  final tripId = data['tripId']; // this is a String!
  final timestamp = data['timestamp'];

  if (tripId != null && timestamp != null) {
    DateTime dateTime;
    try {
      dateTime = timestamp.toDate();
    } catch (_) {
      dateTime = DateTime.tryParse(timestamp.toString()) ?? DateTime.now();
    }

    final formattedDate =
        DateFormat('MMMM d, y \'at\' h:mm a').format(dateTime);

    // Show loading indicator
    showDialog(
      context: navigatorKey.currentState!.overlay!.context,
      barrierDismissible: false,
      builder: (_) => Center(child: CircularProgressIndicator()),
    );

    final images = await fetchTripImages(tripId);

    Navigator.of(navigatorKey.currentState!.overlay!.context).pop(); // Dismiss loader

    // Fetch full trip doc if needed (e.g., for passing to map screen)
    final tripDoc = await FirebaseFirestore.instance.collection('trips').doc(tripId).get();

    showDialog(
      context: navigatorKey.currentState!.overlay!.context,
      builder: (context) => AlertDialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        title: Row(
          children: [
            Icon(Icons.style, color: tealColor),
            SizedBox(width: 8),
            Text('Memory Found!', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.calendar_today, size: 18, color: Colors.grey[600]),
                SizedBox(width: 6),
                Text('Visited on:', style: TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            SizedBox(height: 4),
            Text(formattedDate, style: TextStyle(color: Colors.grey[700], fontSize: 14)),
            SizedBox(height: 12),
            Divider(),
            SizedBox(height: 8),
            Text('Relive this moment by viewing your trip.',
                style: TextStyle(fontStyle: FontStyle.italic)),
            if (images.isNotEmpty) ...[
              SizedBox(height: 12),
              Text('📸 Captured Memories:', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 8),
              SizedBox(
                height: 90,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: images.length,
                  separatorBuilder: (_, __) => SizedBox(width: 8),
                  itemBuilder: (_, index) {
                    final imgUrl = images[index]['image_url'];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
  width: 90,
  height: 90,
  child: ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.network(
      imgUrl,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: loadingProgress.expectedTotalBytes != null
                ? loadingProgress.cumulativeBytesLoaded /
                    loadingProgress.expectedTotalBytes!
                : null,
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.grey[300],
        child: Icon(Icons.broken_image, color: Colors.grey[600]),
      ),
    ),

                      ),
                    ),);
                  },
                ),
              ),
            ]
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.pushNamed(
                context,
                AppRoutes.map,
                arguments: {'trip': tripDoc.data()}, // now we have the actual trip
              );
            },
            icon: Icon(Icons.map, color: tealColor),
            label: Text('View Trip', style: TextStyle(color: tealColor)),
          ),
        ],
      ),
    );
  }
}



// Function to start background location tracking using Geolocator
  void startBackgroundTracking() async {
  bool permissionGranted = await requestLocationPermission();
  if (!permissionGranted) {
    print("Location permission not granted.");
    return;
  }

  print('Started background location tracking');

  Geolocator.getPositionStream(
    locationSettings: const LocationSettings(
      accuracy: LocationAccuracy.best,
      distanceFilter: 10, // Update every 10 meters
    ),
  ).listen((Position position) {
    LatLng newLocation = LatLng(position.latitude, position.longitude);
    print("New location received: $newLocation");

    // Update the user's location and check for revisited locations
    updateUserLocation(newLocation);
 
    checkForRevisitedLocations(newLocation); // Call the method
  }, onError: (error) {
    print("Error in location stream: $error");
  });
}

Future<List<Map<String, dynamic>>> fetchTripImages(String tripId) async {
  try {
    final imagesRef = FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId)
        .collection('images');

    final snapshot = await imagesRef.get();

    if (snapshot.docs.isEmpty) {
      print('No images found for this trip.');
      return [];
    }

    // Extracting image URLs and relevant data
    final images = snapshot.docs.map((doc) => doc.data()).toList();
    return images;
  } catch (e) {
    print('Error fetching trip images: $e');
    return [];
  }
}
Future<Map<String, dynamic>?> fetchTripById(String tripId) async {
  try {
    final tripDoc = await FirebaseFirestore.instance
        .collection('trips')
        .doc(tripId)
        .get();

    if (tripDoc.exists) {
      return tripDoc.data();
    } else {
      print('Trip not found.');
      return null;
    }
  } catch (e) {
    print('Error fetching trip: $e');
    return null;
  }
}


}
