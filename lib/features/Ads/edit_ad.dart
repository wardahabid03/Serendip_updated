import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:serendip/models/ads_model.dart';
import 'package:serendip/features/Ads/ads_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';

class EditAdScreen extends StatefulWidget {
  final BusinessAd ad;

  const EditAdScreen({super.key, required this.ad});

  @override
  State<EditAdScreen> createState() => _EditAdScreenState();
}

class _EditAdScreenState extends State<EditAdScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _ctaController;

  String ctaType = 'whatsapp';
  File? _imageFile;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.ad.title);
    _descController = TextEditingController(text: widget.ad.description);
    _ctaController = TextEditingController(
      text: widget.ad.cta?.replaceAll('https://wa.me/', '') ?? '',
    );
    if (widget.ad.cta?.startsWith('https://wa.me/') == false) {
      ctaType = 'website';
    }
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<String> _uploadImage(String adId) async {
    if (_imageFile == null) return widget.ad.imageUrl;
    final ref = FirebaseStorage.instance.ref().child('business_ads/$adId.jpg');
    await ref.putFile(_imageFile!);
    return await ref.getDownloadURL();
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSaving = true);

    final updatedImageUrl = await _uploadImage(widget.ad.id);
    final updatedCTA = ctaType == 'whatsapp'
        ? 'https://wa.me/${_ctaController.text.trim()}'
        : _ctaController.text.trim();

    final updatedAd = widget.ad.copyWith(
      title: _titleController.text.trim(),
      description: _descController.text.trim(),
      imageUrl: updatedImageUrl,
      cta: updatedCTA,
    );

    await Provider.of<BusinessAdsProvider>(context, listen: false).updateAd(ad: updatedAd);

    setState(() => isSaving = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Business Ad')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(
                label: 'Business Name',
                controller: _titleController,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label: 'Ad Description',
                controller: _descController,
                maxLines: 4,
              ),
              const SizedBox(height: 20),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Call to Action Type',
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold),
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
                        color: _imageFile == null ? Colors.grey[200] : Colors.transparent,
                        image: _imageFile != null
                            ? DecorationImage(image: FileImage(_imageFile!), fit: BoxFit.cover)
                            : DecorationImage(image: NetworkImage(widget.ad.imageUrl), fit: BoxFit.cover),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: _imageFile == null && widget.ad.imageUrl.isEmpty
                          ? const Center(
                              child: Text(
                                'Tap to upload (800x600)',
                                style: TextStyle(color: Colors.grey),
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
              const SizedBox(height: 30),
              isSaving
                  ? const CircularProgressIndicator()
                  : SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saveChanges,
                        icon: const Icon(Icons.save, color: Colors.white),
                        label: const Text('Save Changes'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.teal,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
    required TextEditingController controller,
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
