import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/Ads/ads_provider.dart';
import 'package:serendip/features/Ads/edit_ad.dart';
import 'package:serendip/features/profile.dart/provider/profile_provider.dart';
import 'package:serendip/models/ads_model.dart';
import '../../../core/constant/colors.dart';

class AdDashboardScreen extends StatefulWidget {
  const AdDashboardScreen({Key? key}) : super(key: key);

  @override
  State<AdDashboardScreen> createState() => _AdDashboardScreenState();
}

class _AdDashboardScreenState extends State<AdDashboardScreen> {
  BusinessAd? businessAd;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAdData();
  }

  Future<void> _fetchAdData() async {
    final userId =
        Provider.of<ProfileProvider>(context, listen: false).currentUserId;
    if (userId == null) return;

    try {
      final adMap =
          await Provider.of<BusinessAdsProvider>(context, listen: false)
              .fetchUserAd(userId);
      if (adMap != null) {
        final String adDocId = adMap['docId'];
        adMap.remove('docId');

        setState(() {
          businessAd = BusinessAd.fromMap(adMap, adDocId);
          isLoading = false;
        });
      } else {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('No ad found'), backgroundColor: Colors.red),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Error fetching ad: $e'),
            backgroundColor: Colors.red),
      );
    }
  }

  void _deleteAd() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Delete Ad"),
        content: const Text("Are you sure you want to delete this ad?"),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final userId =
          Provider.of<ProfileProvider>(context, listen: false).currentUserId;
      try {
        await Provider.of<BusinessAdsProvider>(context, listen: false)
            .deleteUserAd(userId!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Ad deleted successfully'),
                backgroundColor: Colors.green),
          );
          Navigator.pop(context);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to delete ad: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildAdProgressBarWithPlan() {
    final start = businessAd?.adStartDate;
    final end = businessAd?.adEndDate;
    final plan = businessAd?.paymentPlan ?? "free";

    if (start == null || end == null || end.isBefore(start)) {
      return const Text("Ad duration info not available.");
    }

    final now = DateTime.now();
    final totalDays = end.difference(start).inDays;

    if (now.isBefore(start)) {
      final daysUntilStart = start.difference(now).inDays;
      return Text("Ad starts in $daysUntilStart day(s).");
    }

    final rawDaysPassed = now.difference(start).inDays;
    final daysPassed = rawDaysPassed.clamp(0, totalDays);
    final daysLeft = totalDays - daysPassed;
    final percentage = totalDays > 0 ? daysPassed / totalDays : 0.0;

    String planText;
    switch (plan.toLowerCase()) {
      case "monthly":
        planText = "Monthly Plan";
        break;
      case "yearly":
        planText = "Yearly Plan";
        break;
      case "free":
      default:
        planText = "7-Day Free Trial";
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10,horizontal: 16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "Ad Duration",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade300,
                ),
              ),
              Container(
                height: 14,
                width: MediaQuery.of(context).size.width * percentage,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  gradient: const LinearGradient(
                    colors: [Colors.teal, Colors.green],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "$daysLeft day(s) left out of $totalDays",
            style: const TextStyle(fontSize: 14, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.payment, color: Colors.teal, size: 20),
              const SizedBox(width: 8),
              Text(planText,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ad Dashboard'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : businessAd == null
              ? const Center(child: Text('No ad data available.'))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (businessAd!.imageUrl != null &&
                            businessAd!.imageUrl!.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(
                              businessAd!.imageUrl!,
                              height: 220,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: 14),
                        _buildAdProgressBarWithPlan(),

                        // Call to Action Box
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(
                                  color: Colors.black12,
                                  blurRadius: 8,
                                  offset: Offset(0, 4)),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Call to Action",
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  )),
                              const SizedBox(height: 8),
                              Text(
                                businessAd!.cta ?? 'N/A',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: 16,
                                  color: Colors.teal.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Metrics
                        Row(
                          children: [
                            _buildMetricBox("Impressions",
                                businessAd!.impressions.toString()),
                            const SizedBox(width: 12),
                            _buildMetricBox(
                                "CTA Clicks", businessAd!.ctaClicks.toString()),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            EditAdScreen(ad: businessAd!)),
                                  );
                                },
                                icon: const Icon(Icons.edit,color: Colors.white,),
                                label: const Text("Edit Ad"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: tealSwatch,
                                  foregroundColor: Colors.white,
                                  elevation: 4,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _deleteAd,
                                icon: const Icon(Icons.delete),
                                label: const Text("Delete Ad"),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: tealColor,
                                  elevation: 4,
                                  minimumSize: const Size.fromHeight(50),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildMetricBox(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87)),
            const SizedBox(height: 6),
            Text(label,
                style: const TextStyle(fontSize: 14, color: Colors.black54)),
          ],
        ),
      ),
    );
  }
}
