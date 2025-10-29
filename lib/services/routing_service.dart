import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/itinerary.dart';
import '../models/time_selection.dart';

class RoutingService {
  static const String _baseUrl = 'https://api.transitous.org/api/v5/plan';

  static Future<List<Itinerary>> findRoutes({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    TimeSelection? timeSelection,
  }) async {
    final params = {
      'fromPlace': '$fromLat,$fromLon',
      'toPlace': '$toLat,$toLon',
      'withFares': 'true',
      'useRoutedTransfers': 'true',
    };

    // Add time parameter only if user selected a specific time (not "Now")
    if (timeSelection != null && !timeSelection.isNow) {
      // Format: ISO 8601 with Z suffix (e.g., "2019-08-24T14:15:22Z")
      params['time'] = timeSelection.dateTime.toUtc().toIso8601String();

      // Add arriveBy parameter if user wants to arrive by this time
      if (timeSelection.isArriveBy) {
        params['arriveBy'] = 'true';
      }
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> direct = data['direct'] ?? [];
        final List<dynamic> itineraries = data['itineraries'] ?? [];

        final List<Itinerary> result = [];
        result.addAll(direct.map((item) => Itinerary.fromJson(item, isDirect: true)));
        result.addAll(itineraries.map((item) => Itinerary.fromJson(item)));

        return result;
      } else {
        print('API Error - Status: ${response.statusCode}');
        print('API Error - Body: ${response.body}');
        throw Exception('Failed to load routes: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception in findRoutes: $e');
      rethrow;
    }
  }
}
