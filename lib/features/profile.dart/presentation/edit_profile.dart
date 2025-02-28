import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/utils/button.dart';
import '../../../core/utils/text_input_field.dart';
import '../provider/profile_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  String? _profileImageUrl;
  bool _isLocationEnabled = false;
  bool _isPublicAccount = true;

  Future<void> _loadUserProfile() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    try {
      final userProfile = await profileProvider.fetchUserProfile();
      setState(() {
        _usernameController.text = userProfile['username'] ?? '';
        _emailController.text = userProfile['email'] ?? '';
        _dobController.text = userProfile['dob'] ?? '';
        _profileImageUrl = userProfile['profileImage'];
        _isLocationEnabled = userProfile['locationEnabled'] ?? false;
        _isPublicAccount = userProfile['isPublic'] ?? true;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: ${e.toString()}')),
      );
    }
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.request();
    setState(() {
      _isLocationEnabled = status.isGranted;
    });
    
    if (!status.isGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permission is required for better experience'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_isLocationEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable location services to continue'),
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

    try {
      await profileProvider.saveUserProfile(
        username: _usernameController.text,
        email: _emailController.text,
        dob: _dobController.text,
        isPublic: _isPublicAccount,
        profileImage: _profileImageUrl ?? '',
        locationEnabled: _isLocationEnabled,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.pop(context); // Return to previous screen
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: ${e.toString()}')),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);

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
        SnackBar(content: Text('Error uploading image: ${e.toString()}')),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        surfaceTintColor: isDarkMode ? Colors.black : Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
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
                          : AssetImage(
                              isDarkMode
                                  ? 'assets/dark/profile.png'
                                  : 'assets/light/profile.png',
                            ) as ImageProvider,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickAndUploadImage,
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
                // enabled: false, // Email is read-only
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
              ),
              const SizedBox(height: 30),
              PrimaryButton(
                text: 'Save Changes',
                onPressed: _saveProfile,
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