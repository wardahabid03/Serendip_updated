import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:serendip/features/Trip_Tracking/provider/trip_provider.dart';
import '../../../../core/routes.dart';
import '../../provider/profile_provider.dart';

class TripCard extends StatefulWidget {
  final Map<String, dynamic> trip;
  final bool isCurrentUser;
  final String? coverPhoto;
  final Function(String) onTripDeleted;

  const TripCard({
    required this.trip,
    required this.isCurrentUser,
    required this.onTripDeleted,
    this.coverPhoto,
    Key? key,
  }) : super(key: key);

  @override
  State<TripCard> createState() => _TripCardState();
}

class _TripCardState extends State<TripCard> {
  List<String> collaboratorNames = [];
  bool isLoading = true;

  late final String? _coverPhoto; // ✅ Cached cover photo

  @override
  void initState() {
    super.initState();
    _coverPhoto = widget.coverPhoto; // ✅ Set once
    _fetchCollaborators();
  }

  Future<void> _fetchCollaborators() async {
    final profileProvider =
        Provider.of<ProfileProvider>(context, listen: false);
    List<dynamic> collaborators = widget.trip['collaborators'] ?? [];

    List<String> names = await Future.wait(
      collaborators.map((userId) => profileProvider.getUsernameById(userId)),
    );

    setState(() {
      collaboratorNames = names;
      isLoading = false;
    });
  }

  String _formatDate(String timestamp) {
    try {
      final dateTime = DateTime.parse(timestamp);
      return "${dateTime.day}-${dateTime.month}-${dateTime.year}";
    } catch (e) {
      return "Invalid Date";
    }
  }

  String _getCollaboratorsDisplay() {
    if (collaboratorNames.length <= 1) return "Solo Trip";
    return collaboratorNames.length > 2
        ? "${collaboratorNames.take(2).join(", ")} +${collaboratorNames.length - 2} more"
        : collaboratorNames.join(", ");
  }

  void _confirmDeleteTrip() async {
    final confirm = await showDialog<bool>(
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

    if (confirm == true) _deleteTrip();
  }

  void _deleteTrip() async {
    try {
      await Provider.of<TripProvider>(context, listen: false)
          .deleteTrip(widget.trip['tripId']);
      widget.onTripDeleted(widget.trip['tripId']);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text("Failed to delete trip. Please try again.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final String tripName = widget.trip['trip_name'] ?? 'Unnamed Trip';
    final String createdAt = _formatDate(widget.trip['created_at']);

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
              // 🖼️ Cover Image
              Positioned.fill(
                child: _coverPhoto != null && _coverPhoto.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _coverPhoto,
                        fit: BoxFit.cover,
                      )
                    : Container(color: Colors.grey[300]),
              ),

              // 🌈 Gradient Overlay
              Positioned.fill(
                child: Container(
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
                ),
              ),

              // 📝 Trip Info
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
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
                    if (collaboratorNames.length > 1) ...[
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
                                  : "Collaborators: ${_getCollaboratorsDisplay()}",
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

              // ❌ Delete Button
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
