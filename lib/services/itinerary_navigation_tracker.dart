import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../utils/geo_utils.dart';
import '../utils/itinerary_leg_utils.dart';
import '../utils/itinerary_navigation.dart';
import 'location_service.dart';

/// Shared read surface between the foreground-only [ItineraryNavigationTracker]
/// and [BackgroundNavigationBridge] (which mirrors a background-service-hosted
/// tracker), so UI code can render either without knowing which is live.
abstract class NavigationProgressState implements Listenable {
  bool get isActive;
  bool get arrived;
  bool get gpsSignalLost;
  int get currentLegIndex;
  double? get remainingWalkMeters;
  int? get remainingStops;

  void stop();

  /// Makes [legIndex] the monitored leg (e.g. the user manually swiped the
  /// carousel to it), recomputing progress from the last known GPS fix
  /// rather than resetting to the start of that leg.
  void jumpToLeg(int legIndex);
}

/// Tracks a user's live GPS progress along an itinerary's legs, advancing
/// [currentLegIndex] on arrival and surfacing remaining distance/stops.
class ItineraryNavigationTracker extends ChangeNotifier
    implements NavigationProgressState {
  ItineraryNavigationTracker(this.legs);

  final List<DisplayLegInfo> legs;

  static const double _arrivalThresholdMeters = 25;
  static const double _stopThresholdMeters = 120;
  static const Duration _staleAfter = Duration(seconds: 15);
  static const Duration _staleCheckInterval = Duration(seconds: 5);

  StreamSubscription<Position>? _positionSub;
  Timer? _staleTimer;
  DateTime? _lastFixTime;
  LatLng? _lastPosition;
  int _stopIndex = 0;

  bool isActive = false;
  bool arrived = false;
  bool gpsSignalLost = false;
  int currentLegIndex = 0;
  double? remainingWalkMeters;
  int? remainingStops;

  /// Fraction (0..1) of the current leg's distance completed — unlike
  /// [remainingStops], this moves continuously with GPS position rather
  /// than only on reaching a new stop. Used to drive the notification's
  /// progress bar smoothly without changing the displayed stop count.
  double legProgress = 0;

  /// GPS fixes received since the monitored leg began, which is how much the
  /// pace read from it can be trusted.
  int fixesOnLeg = 0;

  bool _virtualEtaLatched = false;

  /// How long the monitored ride has left by the rider's own pace, once that
  /// differs from its timetable by enough to say so; null while the timetable
  /// serves. See [virtualRemaining].
  ///
  /// Once given it is given for the rest of the leg, so the line does not go
  /// back to a time of day as the two come within the margin again.
  Duration? virtualRemainingNow({DateTime? now}) {
    if (currentLegIndex >= legs.length) return null;
    final remaining = virtualRemaining(
      leg: legs[currentLegIndex].leg,
      legProgress: legProgress,
      fixes: fixesOnLeg,
      now: now ?? DateTime.now(),
      latched: _virtualEtaLatched,
    );
    if (remaining != null) _virtualEtaLatched = true;
    return remaining;
  }

  void start(LatLng initialPos, {int? startLegIndex}) {
    if (isActive || legs.isEmpty) return;
    isActive = true;
    arrived = false;
    gpsSignalLost = false;
    currentLegIndex = startLegIndex ?? _nearestLegIndex(initialPos);
    _resetLegProgress();
    _lastFixTime = DateTime.now();
    _positionSub = LocationService.positionStream().listen(
      _onPosition,
      onError: (Object error, StackTrace stackTrace) {
        developer.log(
          'Navigation position stream error',
          name: 'ItineraryNavigationTracker',
          error: error,
          stackTrace: stackTrace,
        );
      },
    );
    _staleTimer = Timer.periodic(_staleCheckInterval, (_) => _checkStale());
    notifyListeners();
  }

  void stop() {
    if (!isActive) return;
    unawaited(_positionSub?.cancel());
    _positionSub = null;
    _staleTimer?.cancel();
    _staleTimer = null;
    isActive = false;
    notifyListeners();
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }

  int _nearestLegIndex(LatLng pos) {
    int bestIndex = 0;
    double bestDistance = double.infinity;
    for (int i = 0; i < legs.length; i++) {
      for (final point in stopWaypoints(legs[i].leg)) {
        final distance = coordinateDistanceInMeters(
          pos.latitude,
          pos.longitude,
          point.latitude,
          point.longitude,
        );
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = i;
        }
      }
    }
    return bestIndex;
  }

  void _resetLegProgress() {
    _stopIndex = 0;
    legProgress = 0;
    fixesOnLeg = 0;
    _virtualEtaLatched = false;
    final leg = legs[currentLegIndex].leg;
    if (leg.mode == 'WALK') {
      remainingWalkMeters = leg.distance;
      remainingStops = null;
    } else {
      remainingWalkMeters = null;
      remainingStops = stopWaypoints(leg).length - 1;
    }
  }

  void _onPosition(Position position) {
    _lastFixTime = DateTime.now();
    _lastPosition = LatLng(position.latitude, position.longitude);
    if (gpsSignalLost) gpsSignalLost = false;
    if (currentLegIndex >= legs.length) return;

    fixesOnLeg++;
    _recomputeProgressFromPosition(_lastPosition!, advanceFrom: _stopIndex);
    // Settles whether the pace is now to be told, while it is being learned,
    // so the notification only has to ask.
    virtualRemainingNow();

    final leg = legs[currentLegIndex].leg;
    final hasArrived = leg.mode == 'WALK'
        ? (remainingWalkMeters ?? double.infinity) <= _arrivalThresholdMeters
        : _stopIndex >= stopWaypoints(leg).length - 1;
    if (hasArrived) _advanceLeg();
    notifyListeners();
  }

  /// Recomputes [remainingWalkMeters]/[remainingStops] for the currently
  /// monitored leg from [pos], without triggering an arrival/advance.
  /// [advanceFrom] lets the live GPS path keep scanning forward from the
  /// stop it already reached; manual leg jumps always scan from the start
  /// of the (newly selected) leg since there's no continuity to preserve.
  void _recomputeProgressFromPosition(LatLng pos, {int advanceFrom = 0}) {
    if (currentLegIndex >= legs.length) return;
    final leg = legs[currentLegIndex].leg;
    if (leg.mode == 'WALK') {
      remainingWalkMeters = coordinateDistanceInMeters(
        pos.latitude,
        pos.longitude,
        leg.toLat,
        leg.toLon,
      );
    } else {
      final waypoints = stopWaypoints(leg);
      _stopIndex = advanceStopIndex(
        waypoints,
        pos,
        advanceFrom,
        thresholdMeters: _stopThresholdMeters,
      );
      remainingStops = waypoints.length - 1 - _stopIndex;
    }
    legProgress = legDistanceProgress(stopWaypoints(leg), pos, _stopIndex);
  }

  /// Makes [legIndex] the monitored leg, e.g. because the user manually
  /// swiped the carousel to it or tapped a leg-step notification action.
  /// Recomputes progress from the last known GPS fix (if any) instead of
  /// assuming the user is at the start of that leg, since they may have
  /// already been somewhere along it.
  void jumpToLeg(int legIndex) {
    if (!isActive || legIndex < 0 || legIndex >= legs.length) return;
    if (legIndex == currentLegIndex) return;
    currentLegIndex = legIndex;
    _resetLegProgress();
    final pos = _lastPosition;
    if (pos != null) _recomputeProgressFromPosition(pos);
    notifyListeners();
  }

  void _advanceLeg() {
    currentLegIndex++;
    if (currentLegIndex >= legs.length) {
      arrived = true;
      stop();
      return;
    }
    _resetLegProgress();
  }

  void _checkStale() {
    final lastFix = _lastFixTime;
    if (lastFix == null) return;
    final isStale = DateTime.now().difference(lastFix) > _staleAfter;
    if (isStale != gpsSignalLost) {
      gpsSignalLost = isStale;
      notifyListeners();
    }
  }

  /// Manual stop-by-stop step, for transit legs only (e.g. when GPS is
  /// unavailable underground). No-op on walk legs.
  void stepStopForward() {
    if (!isActive || currentLegIndex >= legs.length) return;
    final leg = legs[currentLegIndex].leg;
    if (leg.mode == 'WALK') return;
    final waypoints = stopWaypoints(leg);
    if (_stopIndex >= waypoints.length - 1) {
      _advanceLeg();
    } else {
      _stopIndex++;
      remainingStops = waypoints.length - 1 - _stopIndex;
    }
    notifyListeners();
  }

  void stepStopBackward() {
    if (!isActive || currentLegIndex >= legs.length) return;
    final leg = legs[currentLegIndex].leg;
    if (leg.mode == 'WALK' || _stopIndex <= 0) return;
    _stopIndex--;
    remainingStops = stopWaypoints(leg).length - 1 - _stopIndex;
    notifyListeners();
  }

  /// Manual leg-by-leg step, works for any leg type.
  void stepLegForward() {
    if (!isActive || legs.isEmpty) return;
    if (currentLegIndex >= legs.length - 1) {
      _advanceLeg();
      notifyListeners();
    } else {
      jumpToLeg(currentLegIndex + 1);
    }
  }

  void stepLegBackward() {
    if (!isActive || currentLegIndex <= 0) return;
    jumpToLeg(currentLegIndex - 1);
  }
}
