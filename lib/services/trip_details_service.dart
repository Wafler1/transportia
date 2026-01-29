import 'dart:convert';
import 'package:http/http.dart' as http;
import '../environment.dart';
import '../models/itinerary.dart';

class TripDetailsService {
  static Future<Itinerary> fetchTripDetails({required String tripId}) async {
    final uri = Uri.https(Environment.transitousHost, '/api/v5/trip', {
      'tripId': tripId,
    });

    final response = await http.get(
      uri,
      headers: Environment.transitousHeaders(),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Itinerary.fromJson(json);
    } else {
      throw Exception('Failed to load trip details: ${response.statusCode}');
    }
  }
}
