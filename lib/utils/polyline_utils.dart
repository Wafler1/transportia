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
