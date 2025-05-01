import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/profile.dart/provider/profile_provider.dart';
import 'package:serendip/features/Auth/auth_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constant/colors.dart';
import '../Map_view/controller/map_controller.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Map<String, bool> _localToggles = {};
  bool _isReviewVisible = false;

  @override
  void initState() {
    super.initState();
    _loadReviewVisibility();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final profileProvider =
          Provider.of<ProfileProvider>(context, listen: false);
      profileProvider.fetchUserProfile().then((_) {
        final profile = profileProvider.userProfile;
        if (profile != null) {
          setState(() {
            _localToggles = {
              'isPublic': profile['isPublic'] ?? false,
              'locationEnabled': profile['locationEnabled'] ?? false,
              'showTrips': profile['showTrips'] ?? true,
              'notifyFriendRequests': profile['notifyFriendRequests'] ?? true,
              'notifyTripUpdates': profile['notifyTripUpdates'] ?? true,
            };
          });
        }
      });
    });
  }

  Future<void> _loadReviewVisibility() async {
    final prefs = await SharedPreferences.getInstance();
    final isVisible = prefs.getBool('reviewVisibility');
    if (isVisible != null) {
      setState(() => _isReviewVisible = isVisible);
    }
  }

  Future<void> _saveReviewVisibility(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reviewVisibility', value);
  }

  void _toggleSetting(String key, bool value) {
    setState(() {
      _localToggles[key] = value;
    });

    // Fire off background update to Firebase
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    profileProvider.updateSetting(key, value);
  }

  void _toggleReviewDisplay(bool value) {
    setState(() => _isReviewVisible = value);
    _saveReviewVisibility(value);
    final mapController = Provider.of<MapController>(context, listen: false);
    mapController.toggleReviewLayer(value);
  }

  Future<void> _logout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await Provider.of<AuthProvider>(context, listen: false).logout();
        if (!mounted) return;
        Navigator.of(context)
            .pushNamedAndRemoveUntil('/auth', (route) => false);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Logout failed: ${e.toString()}'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.read<ProfileProvider>().userProfile;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection('Account', [
                    _buildSettingsTile('Email', profile['email'] ?? 'Not set',
                        icon: Icons.email),
                    _buildSettingsTile(
                      'Change Password',
                      'Update your password',
                      icon: Icons.lock,
                      onTap: () =>
                          Navigator.pushNamed(context, '/change-password'),
                    ),
                  ]),
                  _buildSection('Privacy', [
                    _buildSwitchTile(
                      'Public Account',
                      _localToggles['isPublic'] ?? false,
                      icon: Icons.public,
                      onChanged: (value) => _toggleSetting('isPublic', value),
                    ),
                    _buildSwitchTile(
                      'Show Location',
                      _localToggles['locationEnabled'] ?? false,
                      icon: Icons.location_on,
                      onChanged: (value) =>
                          _toggleSetting('locationEnabled', value),
                    ),
                    // _buildSwitchTile(
                    //   'Show Trip History',
                    //   _localToggles['showTrips'] ?? true,
                    //   icon: Icons.map,
                    //   onChanged: (value) => _toggleSetting('showTrips', value),
                    // ),
                    _buildSwitchTile(
                      'Show Reviews on Map',
                      _isReviewVisible,
                      icon: Icons.rate_review,
                      onChanged: (value) => _toggleReviewDisplay(value),
                    ),
                  ]),
                  // _buildSection('Notifications', [
                  //   _buildSwitchTile(
                  //     'Friend Requests',
                  //     _localToggles['notifyFriendRequests'] ?? true,
                  //     icon: Icons.person_add,
                  //     onChanged: (value) =>
                  //         _toggleSetting('notifyFriendRequests', value),
                  //   ),
                  //   _buildSwitchTile(
                  //     'Trip Updates',
                  //     _localToggles['notifyTripUpdates'] ?? true,
                  //     icon: Icons.notifications,
                  //     onChanged: (value) =>
                  //         _toggleSetting('notifyTripUpdates', value),
                  //   ),
                  // ]),
                  _buildSection('Business', [
                    _buildSettingsTile(
                      'Represent Your Business',
                      'Submit an ad & call to action',
                      icon: Icons.business_center,
                      onTap: () async {
                        final profileProvider = Provider.of<ProfileProvider>(
                            context,
                            listen: false);
                        final hasAd = await profileProvider
                            .checkIfUserHasAd(); // Add this method in ProfileProvider

                        if (!mounted) return;

                        if (hasAd) {
                          Navigator.pushNamed(context,
                              '/ad_dashboard'); // Navigate to ad dashboard
                        } else {
                          Navigator.pushNamed(
                              context, '/make_ad'); // Navigate to create ad
                        }
                      },
                    ),
                  ]),
         
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: OutlinedButton(
                      onPressed: () => _logout(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red, width: 2),
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('Log Out',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSettingsTile(String title, String subtitle,
      {required IconData icon, VoidCallback? onTap}) {
    return ListTile(
      leading: Icon(icon, color: tealSwatch),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(String title, bool value,
      {required IconData icon, required ValueChanged<bool> onChanged}) {
    return SwitchListTile(
      secondary: Icon(icon, color: tealSwatch),
      title: Text(title),
      value: value,
      onChanged: onChanged,
      activeColor: eggShellColor,
      activeTrackColor: tealSwatch,
      inactiveTrackColor: Colors.grey,
      inactiveThumbColor: eggShellColor,
    );
  }
}
