import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'package:maplibre_gl/maplibre_gl.dart';

class TransitousMapServiceException implements Exception {
  TransitousMapServiceException(this.message);
  final String message;

  @override
  String toString() => 'TransitousMapServiceException: $message';
}

class MapStop {
  const MapStop({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.stopId,
    this.importance,
  });

  final String id;
  final String name;
  final double lat;
  final double lon;
  final String? stopId;
  final double? importance;

  LatLng get latLng => LatLng(lat, lon);

  factory MapStop.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    final lat = (json['lat'] as num?)?.toDouble();
    final lon = (json['lon'] as num?)?.toDouble();
    if (name == null || lat == null || lon == null) {
      throw TransitousMapServiceException('Invalid stop payload');
    }
    final stopId = json['stopId'] as String?;
    final importance = (json['importance'] as num?)?.toDouble();
    final id = (stopId == null || stopId.isEmpty)
        ? 'stop-${lat.toStringAsFixed(6)}-${lon.toStringAsFixed(6)}'
        : stopId;
    return MapStop(
      id: id,
      name: name,
      lat: lat,
      lon: lon,
      stopId: stopId,
      importance: importance,
    );
  }
}

class MapTripSegment {
  const MapTripSegment({
    required this.tripId,
    this.routeShortName,
    this.displayName,
    this.routeColor,
    this.realTime = false,
    this.mode,
    this.fromName,
    this.toName,
    this.fromLat,
    this.fromLon,
    this.toLat,
    this.toLon,
    this.departure,
    this.arrival,
    this.polyline,
  });

  final String tripId;
  final String? routeShortName;
  final String? displayName;
  final String? routeColor;
  final bool realTime;
  final String? mode;
  final String? fromName;
  final String? toName;
  final double? fromLat;
  final double? fromLon;
  final double? toLat;
  final double? toLon;
  final DateTime? departure;
  final DateTime? arrival;
  final String? polyline;

  factory MapTripSegment.fromJson(Map<String, dynamic> json) {
    final trips = json['trips'];
    String? tripId;
    String? routeShortName;
    String? displayName;
    if (trips is List && trips.isNotEmpty && trips.first is Map) {
      final trip = trips.first as Map;
      tripId = trip['tripId'] as String?;
      routeShortName = trip['routeShortName'] as String?;
      displayName = trip['displayName'] as String?;
    }
    if (tripId == null || tripId.isEmpty) {
      throw TransitousMapServiceException('Trip segment missing tripId');
    }

    final from = json['from'] as Map<String, dynamic>?;
    final to = json['to'] as Map<String, dynamic>?;
    final fromLat = (from?['lat'] as num?)?.toDouble();
    final fromLon = (from?['lon'] as num?)?.toDouble();
    final toLat = (to?['lat'] as num?)?.toDouble();
    final toLon = (to?['lon'] as num?)?.toDouble();

    return MapTripSegment(
      tripId: tripId,
      routeShortName: routeShortName,
      displayName: displayName,
      routeColor: json['routeColor'] as String?,
      realTime:
          (json['realTime'] as bool?) ?? (json['realtime'] as bool?) ?? false,
      mode: json['mode'] as String?,
      fromName: from?['name'] as String?,
      toName: to?['name'] as String?,
      fromLat: fromLat,
      fromLon: fromLon,
      toLat: toLat,
      toLon: toLon,
      departure: json['departure'] != null
          ? DateTime.tryParse(json['departure'] as String)
          : null,
      arrival: json['arrival'] != null
          ? DateTime.tryParse(json['arrival'] as String)
          : null,
      polyline: json['polyline'] as String?,
    );
  }
}

class TransitousMapService {
  static const _host = 'api.transitous.org';
  static const _tripsPath = '/api/v5/map/trips';
  static const _stopsPath = '/api/v1/map/stops';

  static Future<List<MapTripSegment>> fetchTripSegments({
    required double zoom,
    required LatLngBounds bounds,
    required DateTime startTime,
    required DateTime endTime,
  }) async {
    final south = math.min(
      bounds.southwest.latitude,
      bounds.northeast.latitude,
    );
    final north = math.max(
      bounds.southwest.latitude,
      bounds.northeast.latitude,
    );
    final west = math.min(
      bounds.southwest.longitude,
      bounds.northeast.longitude,
    );
    final east = math.max(
      bounds.southwest.longitude,
      bounds.northeast.longitude,
    );

    final params = <String, String>{
      'zoom': zoom.toStringAsFixed(2),
      'min': '${south.toStringAsFixed(6)},${east.toStringAsFixed(6)}',
      'max': '${north.toStringAsFixed(6)},${west.toStringAsFixed(6)}',
      'startTime': _formatIso8601Millis(startTime),
      'endTime': _formatIso8601Millis(endTime),
    };

    final uri = Uri.https(_host, _tripsPath, params);
    try {
      final resp = await http.get(uri, headers: {'accept': 'application/json'});
      if (resp.statusCode != 200) {
        throw TransitousMapServiceException(
          'Unexpected status ${resp.statusCode}',
        );
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! List) {
        throw TransitousMapServiceException('Unexpected trip payload');
      }
      final segments = <MapTripSegment>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          segments.add(MapTripSegment.fromJson(entry));
        } catch (_) {}
      }
      return segments;
    } catch (e) {
      if (e is TransitousMapServiceException) rethrow;
      throw TransitousMapServiceException('Failed to fetch trips: $e');
    }
  }

  static Future<List<MapStop>> fetchStops({
    required LatLngBounds bounds,
  }) async {
    final south = math.min(
      bounds.southwest.latitude,
      bounds.northeast.latitude,
    );
    final north = math.max(
      bounds.southwest.latitude,
      bounds.northeast.latitude,
    );
    final west = math.min(
      bounds.southwest.longitude,
      bounds.northeast.longitude,
    );
    final east = math.max(
      bounds.southwest.longitude,
      bounds.northeast.longitude,
    );

    final params = <String, String>{
      'min': '${south.toStringAsFixed(6)},${east.toStringAsFixed(6)}',
      'max': '${north.toStringAsFixed(6)},${west.toStringAsFixed(6)}',
    };

    final uri = Uri.https(_host, _stopsPath, params);
    try {
      final resp = await http.get(uri, headers: {'accept': 'application/json'});
      if (resp.statusCode != 200) {
        throw TransitousMapServiceException(
          'Unexpected status ${resp.statusCode}',
        );
      }
      final decoded = jsonDecode(resp.body);
      if (decoded is! List) {
        throw TransitousMapServiceException('Unexpected stop payload');
      }
      final stops = <MapStop>[];
      for (final entry in decoded) {
        if (entry is! Map<String, dynamic>) continue;
        try {
          stops.add(MapStop.fromJson(entry));
        } catch (_) {}
      }
      return stops;
    } catch (e) {
      if (e is TransitousMapServiceException) rethrow;
      throw TransitousMapServiceException('Failed to fetch stops: $e');
    }
  }
}

String _formatIso8601Millis(DateTime dateTime) {
  final utc = dateTime.toUtc();
  final base = utc.toIso8601String();
  final dot = base.indexOf('.');
  if (dot == -1) {
    return base;
  }
  final millis = utc.millisecond.toString().padLeft(3, '0');
  return '${base.substring(0, dot)}.${millis}Z';
}
