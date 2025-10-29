import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/stop_time.dart';

class StopTimesServiceException implements Exception {
  final String message;
  StopTimesServiceException(this.message);
  @override
  String toString() => 'StopTimesServiceException: $message';
}

class StopTimesService {
  static const _host = 'api.transitous.org';
  static const _path = '/api/v5/stoptimes';

  static Future<StopTimesResponse> fetchStopTimes({
    required String stopId,
    int n = 25,
    String? pageCursor,
  }) async {
    final params = <String, String>{
      'stopId': stopId,
      'n': n.toString(),
      'radius': '20',
    };

    if (pageCursor != null) {
      params['pageCursor'] = pageCursor;
    }

    final uri = Uri.https(_host, _path, params);

    try {
      final resp = await http.get(uri, headers: {'accept': 'application/json'});

      if (resp.statusCode != 200) {
        throw StopTimesServiceException(
          'Unexpected status ${resp.statusCode}',
        );
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
