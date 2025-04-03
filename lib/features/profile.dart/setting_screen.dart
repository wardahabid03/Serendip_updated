import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/profile.dart/provider/profile_provider.dart';

import '../../../core/constant/colors.dart';
import 'package:serendip/features/Auth/auth_provider.dart';  // Fixed import pathr


class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<Map<String, dynamic>> _settingsFuture;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() {
    final profileProvider = Provider.of<ProfileProvider>(context, listen: false);
    _settingsFuture = profileProvider.fetchUserProfile();
  }

  Future<void> _logout(BuildContext context) async {
    bool? confirmLogout = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmLogout == true && mounted) {
      try {
        // Get AuthProvider directly from the current context
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        await authProvider.logout();

        if (!mounted) return;

        // Navigate to auth screen and clear the navigation stack
        Navigator.of(context).pushNamedAndRemoveUntil('/auth', (route) => false);
      } catch (e) {
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Logout failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _settingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
           print('Error loading settings: ${snapshot.error}');
          }

          final settings = snapshot.data ?? {};
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection('Account', [
                  _buildSettingsTile('Email', settings['email'] ?? 'Not set', icon: Icons.email),
                  _buildSettingsTile('Password', '********', icon: Icons.lock),
                ]),
                _buildSection('Privacy', [
                  _buildSwitchTile('Public Account', settings['isPublic'] ?? false, icon: Icons.public),
                  _buildSwitchTile('Show Location', settings['locationEnabled'] ?? false, icon: Icons.location_on),
                  _buildSwitchTile('Show Trip History', settings['showTrips'] ?? true, icon: Icons.map),
                ]),
                _buildSection('Notifications', [
                  _buildSwitchTile('Friend Requests', settings['notifyFriendRequests'] ?? true, icon: Icons.person_add),
                  _buildSwitchTile('Trip Updates', settings['notifyTripUpdates'] ?? true, icon: Icons.notifications),
                ]),
                _buildSection('Data & Storage', [
                  _buildSettingsTile('Clear Cache', 'Free up space', icon: Icons.cleaning_services),
                  _buildSettingsTile('Download Data', 'Get a copy of your data', icon: Icons.download),
                ]),
                _buildSection('Support', [
                  _buildSettingsTile('Help Center', 'Get help with the app', icon: Icons.help),
                  _buildSettingsTile('Report a Problem', 'Let us know about issues', icon: Icons.bug_report),
                ]),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: OutlinedButton(
                    onPressed: () => _logout(context),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 2),
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Log Out',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSettingsTile(String title, String subtitle, {required IconData icon}) {
    return ListTile(
      leading: Icon(icon, color: tealSwatch),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {},
    );
  }

  Widget _buildSwitchTile(String title, bool value, {required IconData icon}) {
    return SwitchListTile(
      secondary: Icon(icon, color: tealSwatch),
      title: Text(title),
      value: value,
      onChanged: (newValue) {},
      activeColor: eggShellColor,
      activeTrackColor: tealSwatch,
      inactiveTrackColor: Colors.grey,
      inactiveThumbColor: eggShellColor,
    );
  }
}