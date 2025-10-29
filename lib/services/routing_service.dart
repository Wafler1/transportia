import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/itinerary.dart';
import '../models/time_selection.dart';
import '../models/itinerary_response.dart';

class RoutingService {
  static const String _baseUrl = 'https://api.transitous.org/api/v5/plan';

  static Future<List<Itinerary>> findRoutes({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    TimeSelection? timeSelection,
  }) async {
    // Backwards‑compatible helper that returns only the itineraries list.
    final response = await findRoutesPaginated(
      fromLat: fromLat,
      fromLon: fromLon,
      toLat: toLat,
      toLon: toLon,
      timeSelection: timeSelection,
    );
    return response.itineraries;
  }

  /// Returns itineraries with pagination support. The optional `pageCursor`
  /// parameter is passed straight through to the backend when supplied.
  static Future<ItineraryResponse> findRoutesPaginated({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
    TimeSelection? timeSelection,
    String? pageCursor,
  }) async {
    final params = {
      'fromPlace': '$fromLat,$fromLon',
      'toPlace': '$toLat,$toLon',
      'withFares': 'true',
      'useRoutedTransfers': 'true',
    };

    if (pageCursor != null) {
      params['pageCursor'] = pageCursor;
    }

    // Add time parameter only if user selected a specific time (not "Now")
    if (timeSelection != null && !timeSelection.isNow) {
      params['time'] = timeSelection.dateTime.toUtc().toIso8601String();
      if (timeSelection.isArriveBy) {
        params['arriveBy'] = 'true';
      }
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ItineraryResponse.fromJson(data);
      } else {
        print('API Error - Status: ${response.statusCode}');
        print('API Error - Body: ${response.body}');
        throw Exception('Failed to load routes: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception in findRoutesPaginated: $e');
      rethrow;
    }
  }
}
