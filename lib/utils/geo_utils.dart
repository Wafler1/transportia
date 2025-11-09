import 'dart:math' as math;

const double _earthRadiusMeters = 6371000; // Average Earth radius in meters.

/// Returns the haversine distance in meters between two WGS84 coordinates.
double coordinateDistanceInMeters(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  final dLat = _degreesToRadians(lat2 - lat1);
  final dLon = _degreesToRadians(lon2 - lon1);

  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(_degreesToRadians(lat1)) *
          math.cos(_degreesToRadians(lat2)) *
          math.pow(math.sin(dLon / 2), 2);
  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  return _earthRadiusMeters * c;
}

/// Convenience helper that checks whether two coordinates are within a short
/// [thresholdInMeters] distance of each other.
bool areCoordsClose(
  double lat1,
  double lon1,
  double lat2,
  double lon2, {
  double thresholdInMeters = 10,
}) {
  return coordinateDistanceInMeters(lat1, lon1, lat2, lon2) <=
      thresholdInMeters;
}

double _degreesToRadians(double degrees) => degrees * (math.pi / 180.0);
