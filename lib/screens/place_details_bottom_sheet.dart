import 'package:flutter/material.dart';

class PlaceDetailsBottomSheet extends StatelessWidget {
  final double height;
  final String placeName;
  final String description;
  final String imageUrl;
  final String category1;
  final String category2;
  final String category3;
  final Function(double) onDragUpdate;
  final Function(double) onDragEnd;

  const PlaceDetailsBottomSheet({
    Key? key,
    required this.height,
    required this.placeName,
    required this.description,
    required this.imageUrl,
    required this.category1,
    required this.category2,
    required this.category3,
    required this.onDragUpdate,
    required this.onDragEnd,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: (details) => onDragUpdate(details.primaryDelta!),
      onVerticalDragEnd: (details) => onDragEnd(details.primaryVelocity!),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300), // Smooth transition
          height: MediaQuery.of(context).size.height * height,
          decoration: BoxDecoration(
            color: Colors.teal[50], // Light background for the info section
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.3),
                spreadRadius: 1,
                blurRadius: 5,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed Place Name
              Text(
                placeName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Scrollable Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Place Image
                      Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          image: DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.scaleDown,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Place Description
                      Text(
                        description,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      // Categories Section
                      const Text(
                        "Categories:",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        "$category1, $category2, $category3",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
