import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessAd {
  final String id;
  final String title;
  final String description;
  final String cta; // Call to Action
  final GeoPoint location;
  final double? distance; // computed locally
  final String imageUrl;
  final String ownerId;
  final DateTime createdAt;
  final String paymentPlan; // e.g., 'monthly', 'package'
  final bool isPaymentActive;

  BusinessAd({
    required this.id,
    required this.title,
    required this.description,
    required this.cta,
    required this.location,
    this.distance,
    required this.imageUrl,
    required this.ownerId,
    required this.createdAt,
    required this.paymentPlan,
    required this.isPaymentActive,
  });

  factory BusinessAd.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusinessAd(
      id: doc.id,
      title: data['title'],
      description: data['description'],
      cta: data['cta'],
      location: data['location'],
      imageUrl: data['imageUrl'],
      ownerId: data['ownerId'],
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      paymentPlan: data['paymentPlan'],
      isPaymentActive: data['isPaymentActive'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'cta': cta,
      'location': location,
      'imageUrl': imageUrl,
      'ownerId': ownerId,
      'createdAt': Timestamp.fromDate(createdAt),
      'paymentPlan': paymentPlan,
      'isPaymentActive': isPaymentActive,
    };
  }

  BusinessAd copyWith({
    String? id,
    String? title,
    String? description,
    String? cta,
    GeoPoint? location,
    double? distance,
    String? imageUrl,
    String? ownerId,
    DateTime? createdAt,
    String? paymentPlan,
    bool? isPaymentActive,
  }) {
    return BusinessAd(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      cta: cta ?? this.cta,
      location: location ?? this.location,
      distance: distance ?? this.distance,
      imageUrl: imageUrl ?? this.imageUrl,
      ownerId: ownerId ?? this.ownerId,
      createdAt: createdAt ?? this.createdAt,
      paymentPlan: paymentPlan ?? this.paymentPlan,
      isPaymentActive: isPaymentActive ?? this.isPaymentActive,
    );
  }
}
