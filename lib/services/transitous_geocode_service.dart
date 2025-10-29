import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

class TransitousGeocodeException implements Exception {
  TransitousGeocodeException(this.message, [this.cause]);
  final String message;
  final Object? cause;

  @override
  String toString() => 'TransitousGeocodeException: $message';
}

class TransitousLocationSuggestion {
  TransitousLocationSuggestion({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.type,
    this.country,
    this.defaultArea,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final String type;
  final String? country;
  final String? defaultArea;

  LatLng get latLng => LatLng(lat, lon);

  String get dedupeKey =>
      '${name.toLowerCase()}|${lat.toStringAsFixed(1)}|${lon.toStringAsFixed(1)}';

  String get subtitle {
    final pieces = <String>[];
    if (defaultArea != null && defaultArea!.isNotEmpty) {
      pieces.add(defaultArea!);
    }
    if (country != null && country!.isNotEmpty) {
      pieces.add(country!);
    }
    return pieces.join(' • ');
  }

  int get typePriority {
    final normalized = type.toLowerCase();
    if (normalized.contains('stop')) return 0;
    if (normalized.contains('place')) return 1;
    if (normalized.contains('address')) return 2;
    return 3;
  }

  factory TransitousLocationSuggestion.fromJson(Map<String, dynamic> json) {
    final areas = json['areas'];
    String? defaultArea;
    if (areas is List) {
      for (final area in areas) {
        if (area is Map<String, dynamic> && area['default'] == true) {
          defaultArea = area['name'] as String?;
          break;
        }
      }
    }
    final lat = (json['lat'] as num?)?.toDouble();
    final lon = (json['lon'] as num?)?.toDouble();
    final name = json['name'] as String?;
    final rawId = json['id'] as String?;
    if (lat == null || lon == null || name == null) {
      throw TransitousGeocodeException('Incomplete suggestion payload');
    }
    final id = (rawId == null || rawId.isEmpty) ? _fallbackId(lat, lon) : rawId;
    return TransitousLocationSuggestion(
      id: id,
      name: name,
      lat: lat,
      lon: lon,
      type: (json['type'] as String?) ?? 'STOP',
      country: json['country'] as String?,
      defaultArea: defaultArea,
    );
  }
}

class TransitousGeocodeService {
  static const _host = 'api.transitous.org';
  static const _path = '/api/v1/geocode';
  static const _reversePath = '/api/v1/reverse-geocode';

  static Future<List<TransitousLocationSuggestion>> fetchSuggestions({
    required String text,
    LatLng? placeBias,
    String? type,
  }) async {
    final query = text.trim();
    if (query.length < 3) {
      return const <TransitousLocationSuggestion>[];
    }

    final params = <String, String>{'text': query};

    if (placeBias != null) {
      params['place'] =
          '${placeBias.latitude.toStringAsFixed(6)},${placeBias.longitude.toStringAsFixed(6)}';
      params['placeBias'] = '5';
    }

    if (type != null) {
      params['type'] = type;
    }

    final uri = Uri.https(_host, _path, params);
    try {
      final resp = await http.get(uri, headers: {'accept': 'application/json'});
      if (resp.statusCode != 200) {
        throw TransitousGeocodeException(
          'Unexpected status ${resp.statusCode}',
        );
      }
      final body = resp.body;
      final decoded = jsonDecode(body);
      if (decoded is! List) {
        throw TransitousGeocodeException('Unexpected payload from API');
      }
      final seen = <String>{};
      final suggestions = <TransitousLocationSuggestion>[];
      final orderMap = <TransitousLocationSuggestion, int>{};
      var order = 0;
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          final suggestion = TransitousLocationSuggestion.fromJson(entry);
          final key = suggestion.dedupeKey;
          if (seen.add(key)) {
            suggestions.add(suggestion);
            orderMap[suggestion] = order++;
          }
        } catch (_) {
          continue;
        }
      }
      suggestions.sort((a, b) {
        final byType = a.typePriority.compareTo(b.typePriority);
        if (byType != 0) return byType;
        final ao = orderMap[a] ?? 0;
        final bo = orderMap[b] ?? 0;
        return ao.compareTo(bo);
      });
      return suggestions;
    } catch (err) {
      if (err is TransitousGeocodeException) rethrow;
      throw TransitousGeocodeException('Failed to fetch suggestions', err);
    }
  }

  static Future<TransitousLocationSuggestion?> reverseGeocode({
    required LatLng place,
  }) async {
    final params = <String, String>{
      'place':
          '${place.latitude.toStringAsFixed(6)},${place.longitude.toStringAsFixed(6)}',
    };
    final uri = Uri.https(_host, _reversePath, params);
    try {
      final resp = await http.get(uri, headers: {'accept': 'application/json'});
      if (resp.statusCode != 200) {
        throw TransitousGeocodeException(
          'Unexpected status ${resp.statusCode}',
        );
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! List) {
        throw TransitousGeocodeException('Unexpected payload from API');
      }
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          return TransitousLocationSuggestion.fromJson(entry);
        } catch (_) {
          continue;
        }
      }
      return null;
    } catch (err) {
      if (err is TransitousGeocodeException) rethrow;
      throw TransitousGeocodeException('Failed to reverse geocode', err);
    }
  }
}

String _fallbackId(double lat, double lon) =>
    'lat:${lat.toStringAsFixed(6)},lon:${lon.toStringAsFixed(6)}';
