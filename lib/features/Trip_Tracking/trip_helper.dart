import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:serendip/core/constant/colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:serendip/features/location/location_provider.dart';
import 'package:serendip/features/Trip_Tracking/provider/trip_provider.dart';
import '../../core/utils/text_input_field.dart';

class TripHelper {
  /// **Minimal and Elegant Trip Dialog**
  static Future<Map<String, dynamic>?> _showTripDetailsDialog(BuildContext context) async {
    final TextEditingController tripNameController = TextEditingController();
    final TextEditingController descriptionController = TextEditingController();
    String privacy = "friends";
    Map<String, String> selectedCollaborators = {}; // {userId: username}

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return SimpleDialog(
              title: const Text("New Trip"),
              contentPadding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              children: [
                // Trip Name Input
                TextInputField(
                  controller: tripNameController,
                  hintText: "Trip Name",
                ),
                const SizedBox(height: 10),

                // Description Input
                TextInputField(
                  controller: descriptionController,
                  hintText: "Description (Optional)",
                ),
                const SizedBox(height: 15),

                // Privacy Options (Dropdown)
                const Text("Privacy", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: privacy,
                      isExpanded: true,
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                      icon: const Icon(Icons.arrow_drop_down, color: tealColor),
                      dropdownColor: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      items: [
                        {"value": "only_me", "label": "Only Me", "icon": Icons.lock},
                        {"value": "friends", "label": "Friends", "icon": Icons.people},
                        {"value": "public", "label": "Public", "icon": Icons.public},
                      ].map((item) {
                        return DropdownMenuItem<String>(
                          value: item["value"] as String,
                          child: Row(
                            children: [
                              Icon(item["icon"] as IconData, size: 20, color: tealColor),
                              const SizedBox(width: 10),
                              Text(
                                item["label"] as String,
                                style: const TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (selectedValue) {
                        if (selectedValue != null) {
                          setState(() => privacy = selectedValue);
                        }
                      },
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                // Collaborate Button
                TextButton.icon(
                  onPressed: () async {
                    Map<String, String> collaborators = await _showCollaboratorsDialog(context);
                    setState(() => selectedCollaborators = collaborators);
                  },
                  icon: const Icon(Icons.group_add),
                  label: const Text("Collaborate", style: TextStyle(fontWeight: FontWeight.w600)),
                ),

                // Display Selected Collaborators
                if (selectedCollaborators.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: selectedCollaborators.entries.map((entry) {
                      return Chip(
                        label: Text(entry.value),
                        deleteIcon: const Icon(Icons.close),
                        onDeleted: () {
                          setState(() {
                            selectedCollaborators.remove(entry.key);
                          });
                        },
                      );
                    }).toList(),
                  ),
                ],
                const SizedBox(height: 15),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text("Cancel", style: TextStyle(color: Colors.red)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (tripNameController.text.isNotEmpty) {
                          Navigator.of(context).pop({
                            "name": tripNameController.text,
                            "description": descriptionController.text.isNotEmpty
                                ? descriptionController.text
                                : "A new journey",
                            "privacy": privacy,
                            "collaborators": selectedCollaborators.keys.toList(),
                          });
                        }
                      },
                      child: const Text("Start Trip"),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// **Collaborators Selection Dialog**
  static Future<Map<String, String>> _showCollaboratorsDialog(BuildContext context) async {
    Map<String, String> selectedCollaborators = {}; // {userId: username}
    List<Map<String, dynamic>> friends = [];

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String? cachedFriends = prefs.getString('friends_${FirebaseAuth.instance.currentUser?.uid}');

    if (cachedFriends != null) {
      friends = List<Map<String, dynamic>>.from(jsonDecode(cachedFriends));
    }

    return (await showDialog<Map<String, String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Select Collaborators"),
              content: friends.isEmpty
                  ? const Text("No friends available", style: TextStyle(color: Colors.grey))
                  : SizedBox(
                      height: 300,
                      child: ListView.builder(
                        itemCount: friends.length,
                        itemBuilder: (context, index) {
                          final friend = friends[index];
                          final friendId = friend['userId'];
                          final friendName = friend['username'];

                          return CheckboxListTile(
                            title: Text(friendName),
                            secondary: CircleAvatar(
                              backgroundImage: friend['profileImage'].isNotEmpty
                                  ? NetworkImage(friend['profileImage'])
                                  : null,
                              child: friend['profileImage'].isEmpty ? const Icon(Icons.person) : null,
                            ),
                            value: selectedCollaborators.containsKey(friendId),
                            onChanged: (selected) {
                              setState(() {
                                if (selected == true) {
                                  selectedCollaborators[friendId] = friendName;
                                } else {
                                  selectedCollaborators.remove(friendId);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(selectedCollaborators),
                  child: const Text("Confirm"),
                ),
              ],
            );
          },
        );
      },
    )) ?? {};
  }

  /// **Start a new trip**
  static Future<bool> startTrip(BuildContext context) async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final userId = FirebaseAuth.instance.currentUser?.uid;

    if (userId == null) return false;

    LatLng? userLocation = locationProvider.currentLocation;
    if (userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to get your location. Please try again.'))
      );
      return false;
    }

    final tripDetails = await _showTripDetailsDialog(context);
    if (tripDetails == null) return false;

    tripProvider.startTrip(
      tripDetails["name"],
      userId,
      tripDetails["description"],
      tripDetails["privacy"],
      List<String>.from(tripDetails["collaborators"]),
      userLocation
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Trip started! Your trip will continue recording even if you close the app.'),
        duration: Duration(seconds: 3),
      )
    );

    return true;
  }

  /// **Stop the current trip and record the user's current location**
  static Future<void> stopTrip(BuildContext context) async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    if (!tripProvider.isRecording) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No active trip to stop.")),
      );
      return;
    }

    LatLng? userLocation = locationProvider.currentLocation;
    if (userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Could not get user location.")),
      );
      return;
    }

    await tripProvider.stopTrip(userLocation);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Trip saved successfully!")),
    );
  }
}