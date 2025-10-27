import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/itinerary.dart';

class RoutingService {
  static const String _baseUrl = 'https://api.transitous.org/api/v5/plan';

  static Future<List<Itinerary>> findRoutes({
    required double fromLat,
    required double fromLon,
    required double toLat,
    required double toLon,
  }) async {
    final params = {
      'fromPlace': '$fromLat,$fromLon',
      'toPlace': '$toLat,$toLon',
      'withFares': 'true',
      'useRoutedTransfers': 'true',
    };
    final uri = Uri.parse(_baseUrl).replace(queryParameters: params);

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
      print('Failed to load routes: ${response.body}');
      throw Exception('Failed to load routes');
    }
  }
}
