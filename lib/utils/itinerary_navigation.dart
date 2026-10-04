import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/itinerary.dart';
import 'geo_utils.dart';

List<LatLng> stopWaypoints(Leg leg) {
  return [
    LatLng(leg.fromLat, leg.fromLon),
    for (final stop in leg.intermediateStops) LatLng(stop.lat, stop.lon),
    LatLng(leg.toLat, leg.toLon),
  ];
}

int advanceStopIndex(
  List<LatLng> waypoints,
  LatLng pos,
  int previousIndex, {
  double thresholdMeters = 120,
}) {
  int best = previousIndex;
  for (int i = previousIndex; i < waypoints.length; i++) {
    final distance = coordinateDistanceInMeters(
      pos.latitude,
      pos.longitude,
      waypoints[i].latitude,
      waypoints[i].longitude,
    );
    if (distance <= thresholdMeters) best = i;
  }
  return best;
}

/// Fraction (0..1) of [waypoints]' total length completed, given the
/// furthest waypoint index reached ([stopIndex]) and the live position —
/// interpolates within the current stop-to-stop segment by straight-line
/// distance from its start, so it moves continuously with GPS rather than
/// jumping only when a new stop is reached. Same waypoint list works for
/// both walk and transit legs.
double legDistanceProgress(List<LatLng> waypoints, LatLng? pos, int stopIndex) {
  if (waypoints.length < 2) return 0;

  final segmentLengths = <double>[];
  double total = 0;
  for (int i = 0; i < waypoints.length - 1; i++) {
    final length = coordinateDistanceInMeters(
      waypoints[i].latitude,
      waypoints[i].longitude,
      waypoints[i + 1].latitude,
      waypoints[i + 1].longitude,
    );
    segmentLengths.add(length);
    total += length;
  }
  if (total <= 0) return 0;

  double completed = 0;
  for (int i = 0; i < stopIndex && i < segmentLengths.length; i++) {
    completed += segmentLengths[i];
  }

  if (pos != null && stopIndex < segmentLengths.length) {
    final segmentLength = segmentLengths[stopIndex];
    if (segmentLength > 0) {
      final distanceFromSegmentStart = coordinateDistanceInMeters(
        waypoints[stopIndex].latitude,
        waypoints[stopIndex].longitude,
        pos.latitude,
        pos.longitude,
      );
      completed += distanceFromSegmentStart.clamp(0, segmentLength);
    }
  }

  return (completed / total).clamp(0.0, 1.0);
}

double minDistanceToRoute(List<List<LatLng>> legGeometries, LatLng pos) {
  double best = double.infinity;
  for (final geometry in legGeometries) {
    for (final point in geometry) {
      final distance = coordinateDistanceInMeters(
        pos.latitude,
        pos.longitude,
        point.latitude,
        point.longitude,
      );
      if (distance < best) best = distance;
    }
  }
  return best;
}

String formatWalkRemaining(double meters) {
  if (meters < 1000) {
    return '${meters.round()} m';
  }
  return '${(meters / 1000).toStringAsFixed(2)} km';
}

/// Shared "N stops/m to go" wording, used by both the in-app carousel and the
/// background tracking notification so they never drift apart — except for
/// exactly one stop left, where [nextStopLabel] lets each surface phrase it
/// its own way (e.g. "Next stop" vs. "Your stop is next").
String? progressLabel({
  double? remainingWalkMeters,
  int? remainingStops,
  String nextStopLabel = 'Next stop',
}) {
  if (remainingWalkMeters != null) {
    return '${formatWalkRemaining(remainingWalkMeters)} to go';
  }
  if (remainingStops != null) {
    if (remainingStops <= 0) return 'Arriving now';
    if (remainingStops == 1) return nextStopLabel;
    return '$remainingStops stops to go';
  }
  return null;
}

/// GPS fixes on a ride before its own pace is trusted over the timetable.
const int kVirtualEtaMinFixes = 10;

/// How far along a ride the rider must be, as a fraction of it, before the
/// pace is read from it.
const double kVirtualEtaMinProgress = 0.03;

/// How far the pace may put the arrival from the one the leg gives before
/// the rider is told the pace instead.
const Duration kVirtualEtaMinDiscrepancy = Duration(minutes: 5);

/// How long a ride has left, worked out from how far along it the rider is
/// rather than from its timetable, or null while the timetable still serves.
///
/// A rider who boarded an earlier or a later vehicle than the journey planned
/// is moving along the stops correctly, but [Leg.endTime] is that of the
/// vehicle they were meant to be on. Once they have moved enough to say
/// something — [kVirtualEtaMinFixes] fixes and [kVirtualEtaMinProgress] of the
/// ride — the ride's scheduled length, less the share already covered, is
/// what is left; if arriving then would be more than
/// [kVirtualEtaMinDiscrepancy] from [Leg.endTime], that is what to say.
///
/// [latched] holds the answer once it has been given, so the line does not
/// flip back to a time of day because the two came within the margin again.
Duration? virtualRemaining({
  required Leg leg,
  required double legProgress,
  required int fixes,
  required DateTime now,
  bool latched = false,
}) {
  if (leg.mode == 'WALK') return null;
  if (fixes < kVirtualEtaMinFixes || legProgress < kVirtualEtaMinProgress) {
    return null;
  }

  final scheduledStart = leg.scheduledStartTime;
  final scheduledEnd = leg.scheduledEndTime;
  final scheduled = scheduledStart != null && scheduledEnd != null
      ? scheduledEnd.difference(scheduledStart)
      : Duration(seconds: leg.duration);
  if (scheduled <= Duration.zero) return null;

  final left = (1 - legProgress.clamp(0.0, 1.0));
  final remaining = Duration(
    microseconds: (scheduled.inMicroseconds * left).round(),
  );
  if (latched) return remaining;

  final discrepancy = now.add(remaining).difference(leg.endTime).abs();
  return discrepancy > kVirtualEtaMinDiscrepancy ? remaining : null;
}
