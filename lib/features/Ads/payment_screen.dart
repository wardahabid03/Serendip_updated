import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:serendip/core/constant/colors.dart';
import 'package:serendip/core/routes.dart';
import 'dart:convert';

import 'package:serendip/features/Ads/ads_provider.dart';

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({Key? key}) : super(key: key);

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedPlan = 'yearly'; // default to paid plan
  bool isLoading = true;
  bool showFreeTrial = false;

  @override
  void initState() {
    super.initState();
    _checkFreeTrialStatus();
  }

  Future<void> _checkFreeTrialStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final usedTrial = doc.data()?['hasUsedFreeTrial'] ?? false;

    setState(() {
      showFreeTrial = !usedTrial;
      if (!showFreeTrial && selectedPlan == 'free') {
        selectedPlan = 'monthly'; // fall back to monthly
      }
      isLoading = false;
    });
  }

  Future<void> _handlePayment() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    Duration planDuration;

    if (selectedPlan == 'free') {
      planDuration = const Duration(days: 7);

      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'hasUsedFreeTrial': true,
      }, SetOptions(merge: true));

      final adsProvider =
          Provider.of<BusinessAdsProvider>(context, listen: false);

      await adsProvider.updateUserAdPaymentStatus(
        userId: uid,
        paymentPlan: selectedPlan,
        adStartDate: now,
        adEndDate: now.add(planDuration),
      );
   showDialog(
  context: context,
  builder: (context) {
    return AlertDialog(
      title: Text('Success'),
      content: Text('Your ad has been submitted successfully!\nNow people can see your ad according to thier location'),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close the dialog
            Navigator.pushNamed(context, AppRoutes.display_ad); // Navigate
          },
          child: Text('OK'),
        ),
      ],
    );
  },
);

      return;
    }

    try {
      final int amount = selectedPlan == 'monthly' ? 1500 * 100 : 14400 * 100;
      planDuration = selectedPlan == 'monthly'
          ? const Duration(days: 30)
          : const Duration(days: 365);

      // Stripe payment intent
      final url = Uri.parse(
          "https://us-central1-fast-kiln-434404-m1.cloudfunctions.net/createPaymentIntent");
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'amount': amount,
          'currency': 'pkr',
        }),
      );

      if (response.statusCode != 200) {
        throw Exception(
            'Server returned ${response.statusCode}: ${response.body}');
      }

      final responseData = jsonDecode(response.body);
      final clientSecret = responseData['clientSecret'];

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: 'Your App',
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      final adsProvider =
          Provider.of<BusinessAdsProvider>(context, listen: false);

      await adsProvider.updateUserAdPaymentStatus(
        userId: uid,
        paymentPlan: selectedPlan,
        adStartDate: now,
        adEndDate: now.add(planDuration),
      );

     
showDialog(
  context: context,
  builder: (context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text(
        '🎉 Ad Successfully Published!',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 20,
        ),
      ),
      content: const Text(
        'Congratulations! Your ad is now live and visible to nearby users.\n\n'
        'Your business will reach more potential customers based on their location.\n\n'
        'Thank you for choosing to grow with us!',
        style: TextStyle(
          fontSize: 16,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.pop(context); // Close the dialog
            Navigator.pushNamed(context, AppRoutes.display_ad); // Navigate to ads display
          },
          child: Text(
            'View My Ad',
            style: TextStyle(
              color: Colors.teal,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  },
);




    } catch (e) {
      print('Payment failed: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Payment failed: ${e.toString()}')),
      );
    }
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required List<String> features,
    required String value,
    bool isBestValue = false,
  }) {
    final isSelected = selectedPlan == value;

    return GestureDetector(
      onTap: () => setState(() => selectedPlan = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: isSelected ? Colors.teal[50] : Colors.white,
          border: Border.all(
            color: isSelected ? Colors.teal : Colors.grey.shade300,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 6,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isBestValue)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.orangeAccent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Best Value',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              price,
              style: TextStyle(
                fontSize: 16,
                color: isSelected ? Colors.teal : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            ...features.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle,
                          color: Colors.teal, size: 18),
                      const SizedBox(width: 6),
                      Expanded(child: Text(f)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Choose a Plan'),
      backgroundColor: tealColor,
    ),
    body: isLoading
        ? const Center(child: CircularProgressIndicator())
        : Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (showFreeTrial)
                        _buildPlanCard(
                          title: '1-Week Free Trial',
                          price: 'Try advertising your business for free!',
                          value: 'free',
                          features: const [
                            '7 days full access to ad features',
                            'No credit card required',
                            'Test how your ads perform',
                          ],
                        ),
                      _buildPlanCard(
                        title: 'Monthly Plan',
                        price: 'Rs 1500/month',
                        value: 'monthly',
                        features: const [
                          'Full access to ad placements',
                          'Real-time insights and tracking',
                          'Cancel anytime',
                        ],
                      ),
                      _buildPlanCard(
                        title: 'Yearly Plan',
                        price: 'Rs 14400/year (save 20%)',
                        value: 'yearly',
                        isBestValue: true,
                        features: const [
                          'Everything in Monthly Plan',
                          'Priority support for ad setup',
                          'Best value – save more',
                        ],
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -2),
                    )
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _handlePayment,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Subscribe Now',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
  );
}

}
