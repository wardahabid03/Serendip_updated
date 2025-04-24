import 'package:flutter/material.dart';
import 'package:serendip/core/constant/colors.dart';
import '../routes.dart';

class CustomBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemSelected;

  const CustomBottomNavBar({
    Key? key,
    required this.selectedIndex,
    required this.onItemSelected,
  }) : super(key: key);

  void _onItemTapped(BuildContext context, int index) {
    if (index == 3) {
      Navigator.pushNamed(context, AppRoutes.view_profile, arguments: "userId");
    } else {
      onItemSelected(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double navBarWidth = screenWidth - 40; // Adjust width due to padding (20 left + 20 right)
    double itemWidth = navBarWidth / 4; // Each item's width

    return Padding(
      padding: const EdgeInsets.all(20.0), // Extra padding applied
      child: Stack(
        clipBehavior: Clip.none, // Allows floating icons to overflow
        alignment: Alignment.bottomCenter,
        children: [
          // BottomAppBar (Main Navigation Bar)
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BottomAppBar(
              color: tealColor,
              elevation: 10,
              shape: const CircularNotchedRectangle(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(4, (index) {
                  return _buildNavItem(context, index);
                }),
              ),
            ),
          ),

          // Floating Selected Icon with Box Shadow
          if (selectedIndex >= 0) // Ensures valid index
            Positioned(
              bottom: 30, // Moves selected icon upwards
              left: (itemWidth * selectedIndex) + 10, // Adjust position based on padding
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 8,
                      spreadRadius: 3,
                      offset: const Offset(0, 4), // Slight downward shadow
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Icon(
                    _getIcon(selectedIndex),
                    color: tealColor,
                    size: 32,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNavItem(BuildContext context, int index) {
    return SizedBox(
      width: 60,
      height: 60,
      child: IconButton(
        icon: Icon(
          _getIcon(index),
          color: selectedIndex == index ? Colors.transparent : Colors.white70,
          size: 26,
        ),
        onPressed: () => _onItemTapped(context, index), // Navigate using routes,
      ),
    );
  }

  IconData _getIcon(int index) {
    switch (index) {
      case 0:
        return Icons.home_sharp;
      case 1:
        return Icons.person_search;
      case 2:
        return Icons.campaign_rounded;
      case 3:
        return Icons.person;
      default:
        return Icons.help;
    }
  }
}
