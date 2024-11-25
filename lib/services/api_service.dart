import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/places.dart';  // Ensure you import the Place model

class ApiService {
  static Future<List<Place>?> fetchRecommendations(String query) async {
    final url = 'https://place-recommender-47396002707.us-central1.run.app/recommend';

    // Print the URL being used for the request
    print("Fetching recommendations from URL: $url");

    try {
      // Sending a POST request with the query in the body
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'query': query}),  // Sending query as a JSON object
      );

      // Print the status code and response body for debugging
      print("Response Status Code: ${response.statusCode}");
      print("Response Body: ${response.body}");

      if (response.statusCode == 200) {
        // Successfully fetched data, now map it to a list of Place objects
        print("Recommendations fetched successfully: ${response.body}");

        // Decode the response body
        final List<dynamic> decodedData = json.decode(response.body);

        // Map the decoded data to a list of Place objects
        List<Place> places = decodedData.map((placeJson) {
          return Place.fromJson(placeJson);  // Convert each place to a Place object
        }).toList();

        return places;
      } else {
        print("Error fetching recommendations: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      // Handle any exceptions and print them
      print("Exception occurred: $e");
      return null;
    }
  }
}
