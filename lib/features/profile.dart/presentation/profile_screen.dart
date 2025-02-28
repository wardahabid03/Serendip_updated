import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/core/constant/colors.dart';
import '../../../core/utils/show_dialouge.dart';
import '../../auth/auth_provider.dart';
import '/core/utils/button.dart';
import '../../../core/routes.dart';
import '../../../core/utils/text_input_field.dart';
import '../provider/profile_provider.dart';

import 'package:permission_handler/permission_handler.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  String? _profileImageUrl;
  bool _isLocationEnabled = false;
  bool _isPublicAccount = true;

   @override
  void initState() {
    super.initState();
    autofillEmail();
  }


    void autofillEmail() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    final email = await profileProvider.autofillEmail();
    
    if (email != null) {
      setState(() {
        _emailController.text = email;
      });
    }
  }

Future<void> _checkLocationPermission() async {
  final status = await Permission.location.request();
  setState(() {
    _isLocationEnabled = status.isGranted; // Update state but don't enforce
  });
}

Future<void> _saveProfile(BuildContext context) async {
  final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

  try {
    await profileProvider.saveUserProfile(
      username: _usernameController.text,
      email: _emailController.text,
      dob: _dobController.text,
      isPublic: _isPublicAccount,
      profileImage: _profileImageUrl ?? '',
      locationEnabled: _isLocationEnabled, // Allow users to disable location
    );

    if (!mounted) return;

    // Show success alert
     showDialogBox(
      context,
      animationPath: 'assets/success.json', // Lottie file path
      title: 'Success',
      content: 'Your profile has been created successfully!',
      onConfirm: () => Navigator.of(context).pushReplacementNamed(AppRoutes.map),
    );
  } catch (e) {
    // Show failure alert
  showDialogBox(
      context,
      animationPath: 'assets/error.json', // Lottie file path
      title: 'Error',
      content: 'Profile creation failed. Please try again.',
    );
  }
}


  Future<void> _pickAndUploadImage(BuildContext context) async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);

    try {
      final imageUrl = await profileProvider.pickAndUploadImage();
      if (imageUrl != null) {
        setState(() {
          _profileImageUrl = imageUrl;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image uploaded successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: isDarkMode ? Colors.black : Colors.white,
        automaticallyImplyLeading: false,
        title: const Text(
          'Complete Your Profile',
          style: TextStyle(fontSize: 20),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _profileImageUrl != null
                          ? NetworkImage(_profileImageUrl!)
                          : const AssetImage(
                           'assets/images/profile.png',
                            ) as ImageProvider,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: () => _pickAndUploadImage(context),
                        child: Container(
                          width: 30,
                          height: 30,
                          decoration: BoxDecoration(
                            color: Theme.of(context).primaryColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              TextInputField(
                controller: _usernameController,
                hintText: 'Username',
                prefixIcon: Icons.person_outline,
              ),
              const SizedBox(height: 15),
              TextInputField(
                controller: _emailController,
                hintText: 'Email',
                prefixIcon: Icons.email_outlined,
              ),
              const SizedBox(height: 15),
              TextInputField(
                controller: _dobController,
                hintText: 'Date of Birth',
                keyboardType: TextInputType.datetime,
                prefixIcon: Icons.calendar_today_outlined,
                isDateField: true,
              ),
              const SizedBox(height: 20),
              SwitchListTile(
                title: const Text('Enable Location'),
                subtitle: const Text('Required for better experience'),
                value: _isLocationEnabled,
                onChanged: (bool value) async {
                  if (value) {
                    await _checkLocationPermission();
                  } else {
                    setState(() {
                      _isLocationEnabled = false;
                    });
                  }
                },
                controlAffinity: ListTileControlAffinity
                    .trailing, // Keeps switch on the right
                activeColor: eggShellColor, // White toggle circle
                activeTrackColor: tealSwatch, // Teal track when switched on
                inactiveTrackColor: Colors.grey, // Light grey track when off
                inactiveThumbColor:
                    eggShellColor, // Darker grey toggle circle when off
              ),
              const SizedBox(height: 10),
              SwitchListTile(
                title: const Text('Public Account'),
                subtitle: const Text('Anyone can see your profile'),
                value: _isPublicAccount,
                onChanged: (bool value) {
                  setState(() {
                    _isPublicAccount = value;
                  });
                },
                controlAffinity: ListTileControlAffinity
                    .trailing, // Keeps switch on the right
                activeColor: eggShellColor, // White toggle circle
                activeTrackColor: tealSwatch, // Teal track when switched on
                inactiveTrackColor: Colors.grey, // Light grey track when off
                inactiveThumbColor:
                    eggShellColor, // Darker grey toggle circle when off
              ),
              const SizedBox(height: 30),
              PrimaryButton(
                text: 'Complete Profile',
                onPressed: () => _saveProfile(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _dobController.dispose();
    super.dispose();
  }
}
