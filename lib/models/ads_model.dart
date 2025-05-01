import 'package:cloud_firestore/cloud_firestore.dart';

class BusinessAd {
  final String id;
  final String title;
  final String? description;
  final String? cta;
  final GeoPoint location;
  final double? distance;
  final String imageUrl;
  final String? ownerId;
  final DateTime? createdAt;
  final DateTime? adStartDate;
  final DateTime? adEndDate;
  final String? paymentPlan;
  final bool? isPaymentActive;
  final int? impressions;
  final int? ctaClicks;

  BusinessAd({
    required this.id,
    required this.title,
    this.description,
    this.cta,
    required this.location,
    this.distance,
    required this.imageUrl,
    this.ownerId,
    this.createdAt,
    this.adStartDate,
    this.adEndDate,
    this.paymentPlan,
    this.isPaymentActive,
    this.impressions,
    this.ctaClicks,
  });

  factory BusinessAd.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BusinessAd.fromMap(data, doc.id);
  }

  factory BusinessAd.fromMap(Map<String, dynamic> data, String docId) {
    return BusinessAd(
      id: docId,
      title: data['title'] ?? '',
      description: data['description'],
      cta: data['cta'],
      location: data['location'],
      imageUrl: data['imageUrl'] ?? '',
      ownerId: data['ownerId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      adStartDate: (data['adStartDate'] as Timestamp?)?.toDate(),
      adEndDate: (data['adEndDate'] as Timestamp?)?.toDate(),
      paymentPlan: data['paymentPlan'],
      isPaymentActive: data['isPaymentActive'],
      impressions: data['impressions'] ?? 0,
      ctaClicks: data['ctaClicks'] ?? 0,
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
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : null,
      'adStartDate': adStartDate != null ? Timestamp.fromDate(adStartDate!) : null,
      'adEndDate': adEndDate != null ? Timestamp.fromDate(adEndDate!) : null,
      'paymentPlan': paymentPlan,
      'isPaymentActive': isPaymentActive,
      'impressions': impressions,
      'ctaClicks': ctaClicks,
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
    DateTime? adStartDate,
    DateTime? adEndDate,
    String? paymentPlan,
    bool? isPaymentActive,
    int? impressions,
    int? ctaClicks,
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
      adStartDate: adStartDate ?? this.adStartDate,
      adEndDate: adEndDate ?? this.adEndDate,
      paymentPlan: paymentPlan ?? this.paymentPlan,
      isPaymentActive: isPaymentActive ?? this.isPaymentActive,
      impressions: impressions ?? this.impressions,
      ctaClicks: ctaClicks ?? this.ctaClicks,
    );
  }
}
