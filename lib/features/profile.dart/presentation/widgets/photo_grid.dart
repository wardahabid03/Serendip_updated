import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'gallery_screen.dart';

class PhotoGrid extends StatelessWidget {
  final Map<String, List<Map<String, String>>> tripPhotos; // Trip Name -> List of Image Maps {id, url}

  const PhotoGrid({Key? key, required this.tripPhotos}) : super(key: key);

  static const String placeholderImage = 'https://coffective.com/wp-content/uploads/2018/06/default-featured-image.png.jpg';

  @override
  Widget build(BuildContext context) {
    if (tripPhotos.isEmpty) {
      return const Center(child: Text("No photos available"));
    }

    List<String> allPhotos = tripPhotos.values
        .expand((photos) => photos.map((photo) => photo['url']!))
        .take(5)
        .toList();

    while (allPhotos.length < 5) {
      allPhotos.add(placeholderImage);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Expanded(
            flex: 1,
            child: _buildSquareImage(allPhotos[0], context),
          ),
          const SizedBox(width: 6),
          Expanded(
            flex: 1,
            child: Column(
              children: [
                Row(
                  children: [
                    _buildSmallSquareImage(allPhotos[1], context),
                    const SizedBox(width: 6),
                    _buildSmallSquareImage(allPhotos[2], context),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildSmallSquareImage(allPhotos[3], context),
                    const SizedBox(width: 6),
                    _buildSmallSquareImage(allPhotos[4], context),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// **Creates a large square image with caching**
  Widget _buildSquareImage(String imageUrl, BuildContext context) {
    return GestureDetector(
      onTap: () => _openGallery(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: AspectRatio(
          aspectRatio: 1,
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
            fit: BoxFit.cover,
            width: double.infinity,
          ),
        ),
      ),
    );
  }

  /// **Creates a smaller square image with caching**
  Widget _buildSmallSquareImage(String imageUrl, BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _openGallery(context),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: AspectRatio(
            aspectRatio: 1,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.red),
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }

  void _openGallery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GalleryScreen(tripPhotos: tripPhotos),
      ),
    );
  }
}
