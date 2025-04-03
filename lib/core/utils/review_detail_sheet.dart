import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/Reviews/review_provider.dart';
import '../../models/review_model.dart';

class ReviewDetailSheet extends StatelessWidget {
  final ReviewModel review;
  ReviewDetailSheet({required this.review});

  @override
  Widget build(BuildContext context) {
    final reviewProvider = Provider.of<ReviewProvider>(context);
    final TextEditingController _commentController = TextEditingController();

    return Container(
      padding: EdgeInsets.all(15),
      child: Column(
        children: [
          Text(review.text, style: TextStyle(fontSize: 18)),
          Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: review.comments.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(review.comments[index]['text']),
                  subtitle: Text(review.comments[index]['timestamp'].toDate().toString()),
                );
              },
            ),
          ),
          TextField(
            controller: _commentController,
            decoration: InputDecoration(
              hintText: "Add a comment...",
              suffixIcon: IconButton(
                icon: Icon(Icons.send),
                onPressed: () {
                  reviewProvider.addComment(review.placeId, review.reviewId, _commentController.text);
                  _commentController.clear();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
