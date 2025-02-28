import 'package:flutter/material.dart';
import 'package:serendip/core/constant/colors.dart';
import 'dart:math';

class MapSearchBar extends StatefulWidget {
  final TextEditingController searchController;
  final Function onSearch;
  final String hintText;
  final bool isQuery;

  const MapSearchBar({
    Key? key,
    required this.searchController,
    required this.onSearch,
    required this.hintText,
    required this.isQuery,
  }) : super(key: key);

  @override
  _MapSearchBarState createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar> {
  bool showSuggestions = false;
  final List<String> exampleQueries = [
    "What are some hidden gem lakes in Pakistan that most tourists don’t know about?",
    "Which historical forts in Punjab have the most fascinating stories behind them?",
    "Can you list the most scenic waterfalls in Khyber Pakhtunkhwa that are worth the trip?",
    "Where can I experience the best of Sindh’s cultural and historical heritage?",
    "What are the must-visit natural wonders in Balochistan for adventure seekers?",
    "Where can I experience the most stunning mountain landscapes in Pakistan?",
  ];

  List<String> getRandomQueries() {
    final random = Random();
    final queries = List<String>.from(exampleQueries);
    queries.shuffle(random);
    return queries.take(3).toList();
  }

  @override
  Widget build(BuildContext context) {
    final displayedQueries = getRandomQueries();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: widget.searchController,
            onTap: () {
              if (widget.isQuery) {
                setState(() {
                  showSuggestions = true;
                });
              }
            },
            onChanged: (value) {
              if (value.isNotEmpty) {
                setState(() {
                  showSuggestions = false;
                });
              }
            },
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: tealColor),
                borderRadius: BorderRadius.circular(10.0),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: tealColor, width: 2),
                borderRadius: BorderRadius.circular(10.0),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: tealColor, width: 2),
                borderRadius: BorderRadius.circular(10.0),
              ),
              suffixIcon: IconButton(
                icon: Icon(Icons.search, color: tealColor),
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  widget.onSearch();
                  setState(() {
                    showSuggestions = false;
                  });
                },
              ),
            ),
          ),
        ),
        if (widget.isQuery && showSuggestions)
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 5,
                  spreadRadius: 2,
                )
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: displayedQueries.asMap().entries.map((entry) {
                int index = entry.key;
                String query = entry.value;

                return Column(
                  children: [
                    GestureDetector(
                      onTap: () {
                        widget.searchController.text = query;
                        widget.onSearch();
                        setState(() {
                          showSuggestions = false;
                        });
                      },
                      child: Text(
                        query,
                        style: TextStyle(fontSize: 16, color: Colors.black87),
                      ),
                    ),
                    if (index != displayedQueries.length - 1)
                      Divider(
                        color: Colors.black26,
                      ),
                  ],
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
