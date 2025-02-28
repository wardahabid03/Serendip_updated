import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../../models/places.dart';

class PlaceList extends StatelessWidget {
  final List<Place> places;
  final LatLng userLocation;
  final Function(Place place) onPlaceSelected;

  const PlaceList({
    Key? key,
    required this.places,
    required this.userLocation,
    required this.onPlaceSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: places.length,
      itemBuilder: (context, index) {
        var place = places[index];
        return Column(
          children: [
            ListTile(
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8.0),
                child: Image.network(
                  place.imageUrl,
                  width: 45,
                  height: 45,
                  fit: BoxFit.cover,
                ),
              ),
              title: Text(
                place.name,
                style: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () {
                onPlaceSelected(place);
                
                // Clear the list after selection
                places.clear();
              },
            ),
            // Add a divider only if it's not the last item
            if (index != places.length - 1)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 1, horizontal: 20),
                child: Divider(
                  color: Color.fromARGB(149, 1, 100, 100),
                  thickness: 0.5,
                  height: 0.5,
                ),
              ),
          ],
        );
      },
    );
  }
}
