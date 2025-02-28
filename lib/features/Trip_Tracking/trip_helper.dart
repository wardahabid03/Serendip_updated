import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/location/location_provider.dart';
import 'package:serendip/features/Trip_Tracking/provider/trip_provider.dart';

class TripHelper {
  /// Shows a dialog for trip details and returns a map of details if provided.
  static Future<Map<String, dynamic>?> _showTripDetailsDialog(BuildContext context) async {
    String tripName = "";
    String description = "A new journey";
    String privacy = "friends";
    bool isCollaborative = false;

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text("Start a New Trip"),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    decoration: const InputDecoration(hintText: "Enter trip name"),
                    onChanged: (value) => tripName = value,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    decoration: const InputDecoration(hintText: "Enter description (optional)"),
                    onChanged: (value) => description = value,
                  ),
                  const SizedBox(height: 10),
                  const Text("Select Privacy:"),
                  Column(
                    children: [
                      RadioListTile(
                        title: const Text("Only Me"),
                        value: "only_me",
                        groupValue: privacy,
                        onChanged: (value) => setState(() => privacy = value as String),
                      ),
                      RadioListTile(
                        title: const Text("Friends"),
                        value: "friends",
                        groupValue: privacy,
                        onChanged: (value) => setState(() => privacy = value as String),
                      ),
                      RadioListTile(
                        title: const Text("Public"),
                        value: "public",
                        groupValue: privacy,
                        onChanged: (value) => setState(() => privacy = value as String),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    title: const Text("Collaborative Trip"),
                    value: isCollaborative,
                    onChanged: (value) => setState(() => isCollaborative = value!),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text("Cancel"),
              ),
              TextButton(
                onPressed: () {
                  if (tripName.isNotEmpty) {
                    Navigator.of(context).pop({
                      "name": tripName,
                      "description": description,
                      "privacy": privacy,
                      "collaborators": isCollaborative ? [/* add collaborators here */] : [],
                    });
                  }
                },
                child: const Text("Start"),
              ),
            ],
          );
        });
      },
    );
  }

  /// **Start a new trip with the user's current location**
  static Future<void> startTrip(BuildContext context) async {
    final tripProvider = Provider.of<TripProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: User not authenticated.")),
      );
      return;
    }

    LatLng? userLocation = locationProvider.currentLocation; // ✅ Get current location
    if (userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Could not get user location.")),
      );
      return;
    }

    final tripDetails = await _showTripDetailsDialog(context);
    if (tripDetails == null) return;

    tripProvider.startTrip(
      tripDetails["name"],
      userId,
      tripDetails["description"],
      tripDetails["privacy"],
      List<String>.from(tripDetails["collaborators"]),
      userLocation, // ✅ Pass starting location
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Trip '${tripDetails["name"]}' started!")),
    );
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

    LatLng? userLocation = locationProvider.currentLocation; // ✅ Get current location
    if (userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Error: Could not get user location.")),
      );
      return;
    }

    await tripProvider.stopTrip(userLocation); // ✅ Pass stopping location

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Trip saved successfully!")),
    );
  }
}
