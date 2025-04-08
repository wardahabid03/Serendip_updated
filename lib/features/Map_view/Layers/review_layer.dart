import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:geocoding/geocoding.dart';
import 'package:serendip/core/constant/colors.dart';
import '../../../core/utils/navigator_key.dart';
import '../../../models/review_model.dart';
import '../../Reviews/review_provider.dart';
import 'dart:ui' as ui;
import '../../profile.dart/provider/profile_provider.dart';
import 'map_layer.dart';

class ReviewLayer extends MapLayer {
  final ReviewProvider reviewProvider;
  final BuildContext context;
  final Map<String, BitmapDescriptor> _markerCache = {};
  bool isControllerReady = false;

  ReviewLayer({required this.reviewProvider, required this.context}) {
    print("ReviewLayer initialized");

    // Listen for updates in reviews from the provider
    reviewProvider.addListener(() {
      _preCacheMarkers(); // Re-cache markers whenever reviews change
    });

    // Fetch all reviews when the layer is initialized
    _loadAllReviews();
  }

  bool _isActive = true;

void setActive(bool value) {
  _isActive = value;
  notifyListeners(); // trigger update in MapController
}


@override
Set<Marker> getMarkers() {
  if (!_isActive || !isControllerReady) {
    return {};
  }

  Set<Marker> markers = {};
  print('get markers');

  for (var review in reviewProvider.reviews) {
    final latLng = _getLatLngFromReviewId(review.reviewId);
    final markerIcon =
        _markerCache[review.reviewId] ?? BitmapDescriptor.defaultMarker;

    markers.add(Marker(
      markerId: MarkerId(review.reviewId),
      position: latLng,
      icon: markerIcon,
      infoWindow: InfoWindow(title: review.placeName),
      onTap: () => _showReviewDetails(review),
    ));
  }
  return markers;
}


  @override
  Set<Polyline> getPolylines() => {};

  @override
  Set<Circle> getCircles() => {};

  @override
  void clear() {
    reviewProvider.reviews.clear();
  }

  @override
  void onTap(LatLng position) {
    
  }

void _loadAllReviews() async {
  await reviewProvider.fetchAllReviews();
  await _preCacheMarkers(); // ✅ Ensure new markers are cached immediately
}


Future<void> _preCacheMarkers() async {
  print("Pre-caching markers...");
  if (reviewProvider.reviews.isNotEmpty) {
    for (var review in reviewProvider.reviews) {
      _markerCache[review.reviewId] = await _createCustomMarker(review);
    }
    isControllerReady = true;
    print("Markers pre-cached!");
  } else {
    print("No reviews to cache.");
  }
}


  // Create a custom marker for a review
  Future<BitmapDescriptor> _createCustomMarker(ReviewModel review) async {
    final recorder = ui.PictureRecorder();
    final canvas =
        Canvas(recorder, Rect.fromPoints(Offset(0, 0), Offset(150, 50)));

    final paint = Paint()
      ..color = tealColor
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final rect = RRect.fromLTRBAndCorners(0, 0, 250, 100,
        topLeft: Radius.circular(12),
        topRight: Radius.circular(12),
        bottomLeft: Radius.circular(12),
        bottomRight: Radius.circular(12));

    canvas.drawRRect(rect, paint);

    final textPainter = TextPainter(
      text: TextSpan(
        text: review.text.length > 50
            ? review.text.substring(0, 50) + '...'
            : review.text,
        style: TextStyle(color: Colors.white, fontSize: 30),
      ),
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 230);

    textPainter.paint(canvas, Offset(10, 10));

    final picture = recorder.endRecording();
    final img = await picture.toImage(250, 100);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }


void _showReviewDetails(ReviewModel review) {
  print('Review Tap');
  final _commentController = TextEditingController();

  // Ensure we have a valid context from the navigator
  final currentContext = navigatorKey.currentContext;
  if (currentContext == null) {
    print("Navigator context is null!");
    return;
  }

  showDialog(
    context: currentContext,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text("Review Details"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(review.text, style: TextStyle(fontSize: 16)),
            SizedBox(height: 10),

            if (review.comments.isNotEmpty) ...[
              Text("Comments:", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 5),
              ...review.comments.map((comment) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 5.0),
                  child: Text(
                    '${comment['userName']}: ${comment['text']} - ${_formatTimestamp(comment['timestamp'])}',
                    style: TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
            ],

            SizedBox(height: 10),
            TextField(
              controller: _commentController,
              decoration: InputDecoration(hintText: "Add a comment..."),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text("Close"),
            onPressed: () => Navigator.of(dialogContext, rootNavigator: true).pop(),
          ),
          TextButton(
            child: Text("Submit Comment"),
            onPressed: () async {
              if (_commentController.text.isNotEmpty) {
                final profileProvider =
                    Provider.of<ProfileProvider>(currentContext, listen: false);
                String userName = await profileProvider
                    .getUsernameById(FirebaseAuth.instance.currentUser!.uid);

                await reviewProvider.addComment(
                  currentContext,
                  review.reviewId,
                  _commentController.text,
                );

                _markerCache[review.reviewId] =
                    await _createCustomMarker(review);

                Navigator.of(dialogContext, rootNavigator: true).pop();
                _showReviewDetails(review);
              }
            },
          ),
        ],
      );
    },
  );
}


// Helper method to format the timestamp to a readable string
  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final formattedDate =
        "${date.day}-${date.month}-${date.year} ${date.hour}:${date.minute}";
    return formattedDate;
  }

  // Get LatLng from reviewId
  LatLng _getLatLngFromReviewId(String reviewId) {
    final parts = reviewId.split(',');
    final latitude = double.parse(parts[0]);
    final longitude = double.parse(parts[1]);
    return LatLng(latitude, longitude);
  }
}
