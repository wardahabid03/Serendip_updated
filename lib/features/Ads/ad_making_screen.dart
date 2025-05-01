import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:serendip/core/constant/colors.dart';
import 'package:serendip/features/Ads/ads_provider.dart';
import 'package:serendip/features/Ads/payment_screen.dart';
import 'package:serendip/models/ads_model.dart';
import 'package:uuid/uuid.dart';
import 'package:location/location.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../../core/utils/map_location_picker.dart';

class BusinessAdScreen extends StatefulWidget {
  const BusinessAdScreen({super.key});

  @override
  State<BusinessAdScreen> createState() => _BusinessAdScreenState();
}

class _BusinessAdScreenState extends State<BusinessAdScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ctaController = TextEditingController();

  String businessName = '';
  String adDescription = '';
  String ctaType = 'whatsapp'; // Default selected
  File? imageFile;

  bool isLoading = false;
  bool useCurrentLocation = true;
  GeoPoint? pickedLocation;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        imageFile = File(picked.path);
      });
    }
  }

  Future<GeoPoint?> _getCurrentLocation() async {
    if (!useCurrentLocation && pickedLocation != null) return pickedLocation;

    Location location = Location();
    final locData = await location.getLocation();
    return GeoPoint(locData.latitude ?? 0.0, locData.longitude ?? 0.0);
  }

  Future<String> _uploadImage(File file, String adId) async {
    final ref = FirebaseStorage.instance.ref().child('business_ads/$adId.jpg');
    await ref.putFile(file);
    return await ref.getDownloadURL();
  }

  Future<void> _submitAd() async {
    if (!_formKey.currentState!.validate() || imageFile == null) return;

    setState(() => isLoading = true);

    final id = const Uuid().v4();
    final location = await _getCurrentLocation();
    final imageUrl = await _uploadImage(imageFile!, id);
    final uid = FirebaseAuth.instance.currentUser?.uid;

    if (uid == null || location == null) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error: Location or user missing')),
      );
      return;
    }

    final ctaFinal = ctaType == 'whatsapp'
        ? 'https://wa.me/${_ctaController.text.trim()}'
        : _ctaController.text.trim();

    final ad = BusinessAd(
      id: id,
      title: businessName,
      description: adDescription,
      cta: ctaFinal,
      location: location,
      imageUrl: imageUrl,
      ownerId: uid,
      createdAt: DateTime.now(),
      paymentPlan: '',
      isPaymentActive: false,
    );

    await Provider.of<BusinessAdsProvider>(context, listen: false).addAd(ad);

    setState(() => isLoading = false);
    Navigator.push(context, MaterialPageRoute(builder: (_) => PaymentScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Business Ad')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                label: 'Business Name',
                onChanged: (val) => businessName = val,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Ad Description',
                maxLines: 4,
                onChanged: (val) => adDescription = val,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Call to Action Type',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildCTAChip('whatsapp', 'WhatsApp'),
                  const SizedBox(width: 8),
                  _buildCTAChip('website', 'Website'),
                ],
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: ctaType == 'whatsapp'
                    ? 'WhatsApp Number (e.g., 923001234567)'
                    : 'Website URL',
                controller: _ctaController,
              ),
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 0.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ad Location',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                    ),
                    const SizedBox(height: 12),
             Column(
                        children: [
                          RadioListTile<bool>(
                            value: true,
                            groupValue: useCurrentLocation,
                            onChanged: (val) =>
                                setState(() => useCurrentLocation = val!),
                            title: const Text('Use Current Location'),
                            secondary: const Icon(Icons.my_location),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 5.0),
                          ),
                          const Divider(height: 0),
                          RadioListTile<bool>(
                            value: false,
                            groupValue: useCurrentLocation,
                            onChanged: (val) async {
                              setState(() => useCurrentLocation = val!);
                              final picked = await Navigator.push<GeoPoint>(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const MapLocationPickerScreen()),
                              );
                              if (picked != null) {
                                setState(() => pickedLocation = picked);
                              }
                            },
                            title: const Text('Pick From Map'),
                            secondary: const Icon(Icons.map_outlined),
                            contentPadding:
                                const EdgeInsets.symmetric(horizontal: 5.0),
                          ),
                        ],
                      ),
            
                    if (!useCurrentLocation && pickedLocation != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12, left: 8),
                        child: Text(
                          'Picked: (${pickedLocation!.latitude.toStringAsFixed(4)}, ${pickedLocation!.longitude.toStringAsFixed(4)})',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall!
                              .copyWith(color: Colors.grey[700]),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ad Image (Recommended: 800x600)',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(height: 10),
              GestureDetector(
                onTap: _pickImage,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    double width = constraints.maxWidth;
                    double height = width * 3 / 4;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: width,
                      height: height,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(12),
                        color: imageFile == null
                            ? Colors.grey[200]
                            : Colors.transparent,
                        image: imageFile != null
                            ? DecorationImage(
                                image: FileImage(imageFile!), fit: BoxFit.cover)
                            : null,
                      ),
                      child: imageFile == null
                          ? const Center(
                              child: Text('Tap to upload (800x600)',
                                  style: TextStyle(color: Colors.grey)))
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
              isLoading
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _submitAd,
                        icon: const Icon(Icons.ads_click, color: Colors.white),
                        label: const Text('Submit'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    Function(String)? onChanged,
    TextEditingController? controller,
    int maxLines = 1,
  }) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: Colors.grey),
    );

    return Focus(
      child: Builder(
        builder: (context) {
          final isFocused = Focus.of(context).hasFocus;

          return TextFormField(
            decoration: InputDecoration(
              labelText: label,
              filled: isFocused,
              fillColor: Colors.teal.withOpacity(0.08),
              border: border,
              enabledBorder: border,
              focusedBorder: border.copyWith(
                borderSide: const BorderSide(color: Colors.teal, width: 2),
              ),
            ),
            controller: controller,
            maxLines: maxLines,
            onChanged: onChanged,
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          );
        },
      ),
    );
  }

  Widget _buildCTAChip(String value, String label) {
    final isSelected = ctaType == value;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => setState(() => ctaType = value),
        selectedColor: Colors.teal,
        backgroundColor: Colors.grey[100],
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: isSelected ? 4 : 0,
      ),
    );
  }
}
