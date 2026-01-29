import 'dart:convert';
import 'package:http/http.dart' as http;
import '../environment.dart';
import '../models/stop_time.dart';
import '../utils/time_utils.dart';

class StopTimesServiceException implements Exception {
  final String message;
  StopTimesServiceException(this.message);
  @override
  String toString() => 'StopTimesServiceException: $message';
}

class StopTimesService {
  static Future<StopTimesResponse> fetchStopTimes({
    required String stopId,
    int n = 25,
    String? pageCursor,
    DateTime? startTime,
    bool arriveBy = false,
  }) async {
    final params = <String, String>{
      'stopId': stopId,
      'n': n.toString(),
      'radius': '30',
    };

    if (pageCursor != null) {
      params['pageCursor'] = pageCursor;
    }

    if (startTime != null) {
      params['time'] = formatIso8601Millis(startTime);
    }

    if (arriveBy) {
      params['arriveBy'] = 'true';
    }

    final uri = Uri.https(
      Environment.transitousHost,
      '/api/v5/stoptimes',
      params,
    );

    try {
      final resp = await http.get(
        uri,
        headers: Environment.transitousHeaders(),
      );

      if (resp.statusCode != 200) {
        throw StopTimesServiceException('Unexpected status ${resp.statusCode}');
      }

      final body = resp.body;
      final decoded = jsonDecode(body);

      if (decoded is! Map<String, dynamic>) {
        throw StopTimesServiceException('Unexpected payload from API');
      }

      return StopTimesResponse.fromJson(decoded);
    } catch (e) {
      if (e is StopTimesServiceException) {
        rethrow;
      }
      throw StopTimesServiceException('Failed to fetch stop times: $e');
    }
  }
}
