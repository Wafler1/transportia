import 'dart:math' as math;

import 'package:maplibre_gl/maplibre_gl.dart';

List<LatLng> decodePolyline(String encoded, int precision) {
  final List<LatLng> points = [];
  int index = 0;
  int lat = 0;
  int lng = 0;
  final double factor = math.pow(10, -precision).toDouble();

  while (index < encoded.length) {
    int result = 0;
    int shift = 0;
    int b;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lat += dlat;

    result = 0;
    shift = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
    lng += dlng;

    points.add(LatLng(lat * factor, lng * factor));
  }
  return points;
}

/// Inverse of [decodePolyline] — re-encodes a (possibly sliced) point list
/// back into the same encoded-polyline format, at the same [precision].
String encodePolyline(List<LatLng> points, int precision) {
  final factor = math.pow(10, precision).toDouble();
  final buffer = StringBuffer();
  int prevLat = 0;
  int prevLng = 0;

  for (final point in points) {
    final lat = (point.latitude * factor).round();
    final lng = (point.longitude * factor).round();
    _encodePolylineValue(lat - prevLat, buffer);
    _encodePolylineValue(lng - prevLng, buffer);
    prevLat = lat;
    prevLng = lng;
  }
  return buffer.toString();
}

void _encodePolylineValue(int value, StringBuffer buffer) {
  int v = value < 0 ? ~(value << 1) : (value << 1);
  while (v >= 0x20) {
    buffer.writeCharCode((0x20 | (v & 0x1f)) + 63);
    v >>= 5;
  }
  buffer.writeCharCode(v + 63);
}
