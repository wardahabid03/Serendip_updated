import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../../Trip_Tracking/provider/trip_provider.dart';
import 'image_viewer.dart';

class GalleryScreen extends StatelessWidget {
  final Map<String, List<Map<String, String>>> tripPhotos;

  const GalleryScreen({Key? key, required this.tripPhotos}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ✅ Filter only trips with non-empty photo lists
    final filteredTrips = tripPhotos.entries.where((entry) => entry.value.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Photo Gallery")),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: filteredTrips.isEmpty
            ? const Center(
                child: Text(
                  'No photos available.',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              )
            : ListView(
                children: filteredTrips.map((entry) {
                  String tripId = entry.key;
                  List<Map<String, String>> photos = entry.value;
                  String tripName = photos.first['tripName'] ?? 'Unnamed Trip';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                        child: Text(
                          tripName,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: photos.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 6,
                          mainAxisSpacing: 6,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          return _buildImageTile(context, photos, index, tripId);
                        },
                      ),
                    ],
                  );
                }).toList(),
              ),
      ),
    );
  }

  Widget _buildImageTile(BuildContext context, List<Map<String, String>> photos, int index, String tripId) {
    return GestureDetector(
      onTap: () => _openImageViewer(context, photos, index),
      onLongPress: () {
        String? imageId = photos[index]['id'];
        if (imageId != null && imageId.isNotEmpty) {
          _showDeleteDialog(context, tripId, imageId);
        }
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 1,
          child: CachedNetworkImage(
            imageUrl: photos[index]['url']!,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }

  void _openImageViewer(BuildContext context, List<Map<String, String>> photos, int index) {
    List<String> imageUrls = photos.map((photo) => photo['url']!).toList();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewer(photos: imageUrls, initialIndex: index),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, String tripId, String imageId) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Image?"),
        content: const Text("Are you sure you want to delete this image?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Provider.of<TripProvider>(context, listen: false).deleteTripImage(tripId, imageId);
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
