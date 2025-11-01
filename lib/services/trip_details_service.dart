import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/itinerary.dart';

class TripDetailsService {
  static const String _baseUrl = 'https://api.transitous.org/api/v5';

  static Future<Itinerary> fetchTripDetails({required String tripId}) async {
    final uri = Uri.parse(
      '$_baseUrl/trip',
    ).replace(queryParameters: {'tripId': tripId});

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return Itinerary.fromJson(json);
    } else {
      throw Exception('Failed to load trip details: ${response.statusCode}');
    }
  }
}
