import 'dart:convert';
import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import '../enviroment.dart';
import '../models/itinerary.dart';
import '../models/time_selection.dart';
import '../models/itinerary_response.dart';

class RoutingService {
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

    final uri = Uri.https(
      Environment.transitousHost,
      '/api/v5/plan',
      params,
    );

    try {
      final response = await http.get(
        uri,
        headers: Environment.transitousHeaders(),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        return ItineraryResponse.fromJson(data);
      } else {
        developer.log(
          'API error status: ${response.statusCode}',
          name: 'RoutingService',
        );
        developer.log(
          'API error body: ${response.body}',
          name: 'RoutingService',
        );
        throw Exception('Failed to load routes: ${response.statusCode}');
      }
    } catch (e, stackTrace) {
      developer.log(
        'Exception in findRoutesPaginated',
        name: 'RoutingService',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
