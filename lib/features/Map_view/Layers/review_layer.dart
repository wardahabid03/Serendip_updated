import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/review_detail_sheet.dart';
import '../../../models/review_model.dart';
import '../../Reviews/review_provider.dart';


class ReviewLayer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final reviewProvider = Provider.of<ReviewProvider>(context);
    if (!reviewProvider.showReviews) return SizedBox.shrink();

    return Stack(
      children: reviewProvider.reviews.map((review) {
        return Positioned(
          left: 100, // Replace with calculated map position
          top: 200, // Replace with calculated map position
          child: GestureDetector(
            onTap: () => _showReviewDetails(context, review),
            child: Container(
              width: 200,
              padding: EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 5)],
              ),
              child: Text(
                review.text.length > 50 ? "${review.text.substring(0, 50)}..." : review.text,
                style: TextStyle(fontSize: 14),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showReviewDetails(BuildContext context, ReviewModel review) {
    showModalBottomSheet(
      context: context,
      builder: (context) => ReviewDetailSheet(review: review),
    );
  }
}
