import '../models/itinerary.dart';
import 'geo_utils.dart';

const double kSmallWalkSegmentThresholdMeters = 35.0;

enum DisplayLegType { normal, transfer }

class DisplayLegInfo {
  final Leg leg;
  final int originalIndex;
  final DisplayLegType type;

  const DisplayLegInfo({
    required this.leg,
    required this.originalIndex,
    this.type = DisplayLegType.normal,
  });

  bool get isTransfer => type == DisplayLegType.transfer;
}

List<DisplayLegInfo> buildDisplayLegs(List<Leg> legs) {
  final result = <DisplayLegInfo>[];
  for (int i = 0; i < legs.length; i++) {
    final leg = legs[i];
    if (_shouldHideEdgeWalk(leg, i, legs.length)) continue;

    final type = _shouldShowAsTransfer(leg, i, legs.length)
        ? DisplayLegType.transfer
        : DisplayLegType.normal;

    result.add(DisplayLegInfo(leg: leg, originalIndex: i, type: type));
  }
  return result;
}

bool isShortWalkLeg(
  Leg leg, {
  double thresholdMeters = kSmallWalkSegmentThresholdMeters,
}) {
  if (leg.mode != 'WALK') return false;
  return areCoordsClose(
    leg.fromLat,
    leg.fromLon,
    leg.toLat,
    leg.toLon,
    thresholdInMeters: thresholdMeters,
  );
}

bool _shouldHideEdgeWalk(Leg leg, int index, int total) {
  if (leg.mode != 'WALK') return false;
  final isEdge = index == 0 || index == total - 1;
  if (!isEdge) return false;
  return isShortWalkLeg(leg);
}

bool _shouldShowAsTransfer(Leg leg, int index, int total) {
  if (leg.mode != 'WALK') return false;
  final isEdge = index == 0 || index == total - 1;
  if (isEdge) return false;
  return isShortWalkLeg(leg);
}
