import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/profile.dart/provider/profile_provider.dart';

import '../../../core/constant/colors.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _settingsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error loading settings: ${snapshot.error}'),
            );
          }

          final settings = snapshot.data ?? {};
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection(
                  'Account',
                  [
                    _buildSettingsTile(
                      'Email',
                      settings['email'] ?? 'Not set',
                      icon: Icons.email,
                      onTap: () {
                        // TODO: Implement email change
                      },
                    ),
                    _buildSettingsTile(
                      'Password',
                      '********',
                      icon: Icons.lock,
                      onTap: () {
                        // TODO: Implement password change
                      },
                    ),
                  ],
                ),
                _buildSection(
                  'Privacy',
                  [
                    _buildSwitchTile(
                      'Public Account',
                      settings['isPublic'] ?? false,
                      icon: Icons.public,
                      onChanged: (value) async {
                        // TODO: Implement privacy toggle
                      },
                    ),
                    _buildSwitchTile(
                      'Show Location',
                      settings['locationEnabled'] ?? false,
                      icon: Icons.location_on,
                      onChanged: (value) async {
                        // TODO: Implement location toggle
                      },
                    ),
                    _buildSwitchTile(
                      'Show Trip History',
                      settings['showTrips'] ?? true,
                      icon: Icons.map,
                      onChanged: (value) async {
                        // TODO: Implement trip visibility toggle
                      },
                    ),
                  ],
                ),
                _buildSection(
                  'Notifications',
                  [
                    _buildSwitchTile(
                      'Friend Requests',
                      settings['notifyFriendRequests'] ?? true,
                      icon: Icons.person_add,
                      onChanged: (value) async {
                        // TODO: Implement notification toggle
                      },
                    ),
                    _buildSwitchTile(
                      'Trip Updates',
                      settings['notifyTripUpdates'] ?? true,
                      icon: Icons.notifications,
                      onChanged: (value) async {
                        // TODO: Implement notification toggle
                      },
                    ),
                  ],
                ),
                _buildSection(
                  'Data & Storage',
                  [
                    _buildSettingsTile(
                      'Clear Cache',
                      'Free up space',
                      icon: Icons.cleaning_services,
                      onTap: () {
                        // TODO: Implement cache clearing
                      },
                    ),
                    _buildSettingsTile(
                      'Download Data',
                      'Get a copy of your data',
                      icon: Icons.download,
                      onTap: () {
                        // TODO: Implement data download
                      },
                    ),
                  ],
                ),
                _buildSection(
                  'Support',
                  [
                    _buildSettingsTile(
                      'Help Center',
                      'Get help with the app',
                      icon: Icons.help,
                      onTap: () {
                        // TODO: Implement help center
                      },
                    ),
                    _buildSettingsTile(
                      'Report a Problem',
                      'Let us know about issues',
                      icon: Icons.bug_report,
                      onTap: () {
                        // TODO: Implement problem reporting
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton(
                    onPressed: () {
                      // TODO: Implement logout
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                    ),
                    child: const Text('Log Out'),
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
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
        ),
        ...children,
        const Divider(height: 1),
      ],
    );
  }

  Widget _buildSettingsTile(String title, String subtitle, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: tealSwatch),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(String title, bool value, {
    required IconData icon,
    required ValueChanged<bool> onChanged,
  }) {
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