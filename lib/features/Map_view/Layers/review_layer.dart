import 'dart:math';
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
  void onTap(LatLng position) {}

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

  Future<BitmapDescriptor> _createCustomMarker(ReviewModel review) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromPoints(const Offset(0, 0), const Offset(280, 140)),
  );

  final paint = Paint()
    ..color = tealColor
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  // Bubble background
  final bubbleRect = RRect.fromLTRBR(0, 0, 250, 110, const Radius.circular(30));
  canvas.drawRRect(bubbleRect, paint);

  // Tail
  final tailPath = Path()
    ..moveTo(40, 110)
    ..lineTo(30, 125)
    ..lineTo(60, 110)
    ..close();
  canvas.drawPath(tailPath, paint);

  // Review Text
  final textPainter = TextPainter(
    text: TextSpan(
      text: review.text.length > 50
          ? review.text.substring(0, 50) + '...'
          : review.text,
      style: const TextStyle(color: Colors.white, fontSize: 24),
    ),
    textAlign: TextAlign.left,
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: 230);
  textPainter.paint(canvas, const Offset(12, 12));

  // Draw stars for rating
  const starSize = 16.0;
  const spacing = 4.0;
  final fullStars = review.rating.round();  // Rounded rating for full stars

  final starFillPaint = Paint()
    ..color = Colors.yellow
    ..style = PaintingStyle.fill
    ..isAntiAlias = true;

  final starStrokePaint = Paint()
    ..color = Colors.white
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.2
    ..isAntiAlias = true;

  final starPath = _createStarPath(starSize / 2);

  for (int i = 0; i < fullStars; i++) {
    canvas.save();
    canvas.translate(12 + i * (starSize + spacing), 70);
    canvas.drawPath(starPath, starFillPaint);
    canvas.drawPath(starPath, starStrokePaint);
    canvas.restore();
  }

  final picture = recorder.endRecording();
  final img = await picture.toImage(280, 140);
  final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
  return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
}


Path _createStarPath(double radius) {
  const int points = 5;
  final double innerRadius = radius * 0.5;
  final path = Path();
  final angle = pi / points;

  for (int i = 0; i < 2 * points; i++) {
    final isEven = i.isEven;
    final r = isEven ? radius : innerRadius;
    final x = r * cos(i * angle - pi / 2);
    final y = r * sin(i * angle - pi / 2);
    if (i == 0) {
      path.moveTo(x + radius, y + radius);
    } else {
      path.lineTo(x + radius, y + radius);
    }
  }

  path.close();
  return path;
}



  void _showReviewDetails(ReviewModel review) {
    final context = navigatorKey.currentContext!;
    final _commentController = TextEditingController();
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    double userRating = 0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          minChildSize: 0.5,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (_, scrollController) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: StatefulBuilder(
                builder: (context, setState) {
                  return FutureBuilder<String>(
                    future: profileProvider.getUsernameById(review.userId),
                    builder: (context, snapshot) {
                      final username = snapshot.data ?? 'User';
                      return Column(
                        children: [
                          // 🔒 Fixed Header
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  review.placeName,
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  padding: EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.grey.shade300,
                                  ),
                                  child: Icon(Icons.close),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),

                          // 🔒 Fixed Rating
                          Row(
                            children: List.generate(
                              5,
                              (index) => Icon(
                                index < review.rating
                                    ? Icons.star
                                    : Icons.star_border,
                                color: Colors.amber,
                                size: 20,
                              ),
                            )..add(SizedBox(width: 8)),
                          ),
                          SizedBox(height: 12),

                          // ✅ Scrollable Content (Reviews + Add Comment)
                          Expanded(
                            child: ListView(
                              controller: scrollController,
                              children: [
                                // Section title
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Reviews',
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    // TextButton(
                                    //   onPressed: () {},
                                    //   child: Text('View all',
                                    //       style: TextStyle(color: Colors.grey[600])),
                                    // )
                                  ],
                                ),

                                ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Consumer<ProfileProvider>(
                                    builder: (context, profileProvider, child) {
                                      return FutureBuilder<String?>(
                                        future: profileProvider
                                            .getProfileImageById(review
                                                .userId), // Assuming `userId` is available
                                        builder: (context, snapshot) {
                                          if (snapshot.connectionState ==
                                              ConnectionState.waiting) {
                                            return CircleAvatar(
                                              radius: 20,
                                              backgroundImage: AssetImage(
                                                  "assets/images/avatar.png"),
                                            ); // Placeholder image while loading
                                          }

                                          if (snapshot.hasError) {
                                            return CircleAvatar(
                                              radius: 20,
                                              backgroundImage: AssetImage(
                                                  "assets/images/avatar.png"),
                                            ); // Error image or fallback
                                          }

                                          final profileImageUrl = snapshot.data;
                                          return CircleAvatar(
                                            radius: 20,
                                            backgroundImage: profileImageUrl !=
                                                    null
                                                ? NetworkImage(profileImageUrl)
                                                : AssetImage(
                                                    "assets/images/avatar.png"), // Fallback to default avatar
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  title: Text(review.userName),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _formatTimestamp(review.timestamp),
                                        style: TextStyle(
                                            fontSize: 12, color: Colors.grey),
                                      ),
                                      SizedBox(height: 4),
                                      Text(review.text),
                                    ],
                                  ),
                                ),

                                Divider(),

// Comments
                                ...review.comments.map((comment) {
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: Consumer<ProfileProvider>(
                                      builder:
                                          (context, profileProvider, child) {
                                        return FutureBuilder<String?>(
                                          future: profileProvider
                                              .getProfileImageById(
                                                  comment['userId']),
                                          builder: (context, snapshot) {
                                            ImageProvider backgroundImage;
                                            if (snapshot.connectionState ==
                                                    ConnectionState.waiting ||
                                                snapshot.hasError ||
                                                snapshot.data == null) {
                                              backgroundImage = const AssetImage(
                                                  "assets/images/avatar.png");
                                            } else {
                                              backgroundImage =
                                                  NetworkImage(snapshot.data!);
                                            }

                                            return CircleAvatar(
                                              radius: 20,
                                              backgroundImage: backgroundImage,
                                            );
                                          },
                                        );
                                      },
                                    ),
                                    title: Text(
                                        comment['userName'] ?? 'Anonymous'),
                                    subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _formatTimestamp(
                                              comment['timestamp']),
                                          style: TextStyle(
                                              fontSize: 12, color: Colors.grey),
                                        ),
                                        SizedBox(height: 4),
                                        Text(comment['text']),
                                      ],
                                    ),
                                  );
                                }).toList(),

                                SizedBox(height: 20),

                                // Add comment section
                                Text('Add yours',
                                    style: TextStyle(color: Colors.grey[600])),
                                SizedBox(height: 8),

                                Row(
                                  children: List.generate(5, (index) {
                                    return IconButton(
                                      icon: Icon(
                                        index < userRating
                                            ? Icons.star
                                            : Icons.star_border,
                                        color: Colors.amber,
                                      ),
                                      onPressed: () {
                                        setState(() => userRating = index + 1);
                                      },
                                    );
                                  }),
                                ),
                                SizedBox(height: 8),

                                TextField(
                                  controller: _commentController,
                                  decoration: InputDecoration(
                                    hintText: 'Write your review...',
                                    border: UnderlineInputBorder(),
                                  ),
                                  maxLines: 3,
                                ),
                                SizedBox(height: 16),

                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            Navigator.of(context).pop(),
                                        child: Text('Cancel'),
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () async {
                                          if (_commentController
                                              .text.isNotEmpty) {
                                            final currentUsername =
                                                await profileProvider
                                                    .getUsernameById(
                                              FirebaseAuth
                                                  .instance.currentUser!.uid,
                                            );

                                            await reviewProvider.addComment(
                                              context,
                                              review.reviewId,
                                              _commentController.text,
                                              userRating,
                                            );

                                            _commentController.clear();
                                            userRating = 0.0;

                                            setState(
                                                () {}); // Triggers UI update to show new comment
                                          }
                                        },
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: tealColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          minimumSize: Size.fromHeight(45),
                                        ),
                                        child: Text('Submit'),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 16),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            );
          },
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
