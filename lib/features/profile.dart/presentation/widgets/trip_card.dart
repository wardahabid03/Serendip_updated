import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/Trip_Tracking/provider/trip_provider.dart';

import '../../../../core/routes.dart';
import '../../provider/profile_provider.dart';

class TripCard extends StatefulWidget {
  final Map<String, dynamic> trip;
  final bool isCurrentUser;
  final Function(String) onTripDeleted; // Callback to update UI

  const TripCard({
    required this.trip,
    required this.isCurrentUser,
    required this.onTripDeleted, // Pass function to parent
    Key? key,
  }) : super(key: key);

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard> {
  List<String> collaboratorNames = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCollaborators();
  }

  String _formatDate(String timestamp) {
    try {
      DateTime dateTime = DateTime.parse(timestamp);
      return "${dateTime.day}-${dateTime.month}-${dateTime.year}";
    } catch (e) {
      print("Error parsing date: $e");
      return "Invalid Date";
    }
  }

  Future<void> _fetchCollaborators() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    List<dynamic> collaborators = widget.trip['collaborators'] ?? [];

    List<String> names = await Future.wait(
        collaborators.map((userId) => profileProvider.getUsernameById(userId)));

    setState(() {
      collaboratorNames = names;
      isLoading = false;
    });
  }

  void _confirmDeleteTrip() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Trip?"),
        content: const Text(
            "Are you sure you want to delete this trip? This action cannot be undone."),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _deleteTrip();
    }
  }

  void _deleteTrip() async {
    try {
      print(widget.trip);
      print(widget.trip['tripId']);

      await Provider.of<TripProvider>(context, listen: false)
          .deleteTrip(widget.trip['tripId']);

      // Notify parent widget to remove trip from list
      widget.onTripDeleted(widget.trip['tripId']);
      print('Trip deleted');
    } catch (e) {
      print("Error deleting trip: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Failed to delete trip. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String tripName = widget.trip['trip_name'];
    final String createdAt = _formatDate(widget.trip['created_at']);
    final bool isCollaborative = collaboratorNames.length > 1;

    String collaboratorsDisplay = isCollaborative
        ? (collaboratorNames.length > 2
            ? "${collaboratorNames.take(2).join(", ")} +${collaboratorNames.length - 2} more"
            : collaboratorNames.join(", "))
        : "Solo Trip";

    return GestureDetector(
      onTap: () {
        Navigator.pushNamed(
          context,
          AppRoutes.map,
          arguments: {'trip': widget.trip},
        );
      },
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 6,
              spreadRadius: 2,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              // Background Content
              Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tripName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      createdAt,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    if (isCollaborative) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.group,
                              size: 14, color: Colors.white70),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              isLoading
                                  ? "Loading collaborators..."
                                  : "Collaborators: $collaboratorsDisplay",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Delete Button (Only visible for current user)
              if (widget.isCurrentUser)
                Positioned(
                  top: 6,
                  right: 6,
                  child: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _confirmDeleteTrip,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
