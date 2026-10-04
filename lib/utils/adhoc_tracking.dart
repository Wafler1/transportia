import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import '../models/itinerary.dart';
import '../models/stop_time.dart';
import '../screens/itinerary_map_screen.dart';
import '../services/itinerary_tracking_controller.dart';
import '../services/location_service.dart';
import '../services/trip_details_service.dart';
import '../widgets/destination_stop_picker.dart';
import '../widgets/validation_toast.dart';
import 'custom_page_route.dart';
import 'geo_utils.dart';
import 'haptics.dart';
import 'itinerary_leg_utils.dart';

/// Roughly the same "close enough to the route to be plausibly on it"
/// threshold used for itinerary tracking eligibility elsewhere.
const double _adHocProximityThresholdMeters = 250.0;

/// Starts tracking progress against [stopTime] directly — e.g. tapped from
/// the map's stop popup or a departures list — rather than from a searched
/// itinerary. Requires the user to be physically near the boarding stop;
/// prompts for where they're getting off, then tracks a synthetic
/// single-leg itinerary covering just that sub-range of the trip.
Future<void> startAdHocTracking(
  BuildContext context,
  StopTime stopTime,
) async {
  final hasPermission = await LocationService.ensurePermission();
  if (!context.mounted) return;
  if (!hasPermission) {
    showValidationToast(context, 'Location permission is needed to track a trip.');
    return;
  }

  final pos = await _resolveCurrentPosition();
  if (!context.mounted) return;
  if (pos == null ||
      coordinateDistanceInMeters(
            pos.latitude,
            pos.longitude,
            stopTime.place.lat,
            stopTime.place.lon,
          ) >
          _adHocProximityThresholdMeters) {
    showValidationToast(context, "You're too far from this stop to track it.");
    return;
  }

  Itinerary tripDetails;
  try {
    tripDetails = await TripDetailsService.fetchTripDetails(
      tripId: stopTime.tripId,
    );
  } catch (_) {
    if (!context.mounted) return;
    showValidationToast(context, 'Could not load this trip.');
    return;
  }
  if (!context.mounted || tripDetails.legs.isEmpty) return;

  final fullLeg = tripDetails.legs.first;
  final stops = fullLeg.fullStopSequence;
  final boardingIndex = _findBoardingIndex(stops, stopTime.place);
  if (boardingIndex == null || boardingIndex >= stops.length - 1) {
    showValidationToast(context, 'Could not find this stop on the trip.');
    return;
  }

  final alightingIndex = await showDestinationStopPicker(
    context,
    stops: stops,
    boardingIndex: boardingIndex,
  );
  if (alightingIndex == null || !context.mounted) return;

  final slicedLeg = fullLeg.sliceBetween(boardingIndex, alightingIndex);
  final itinerary = Itinerary(
    duration: slicedLeg.duration,
    startTime: slicedLeg.startTime,
    endTime: slicedLeg.endTime,
    transfers: 0,
    legs: [slicedLeg],
    isDirect: true,
  );

  unawaited(Haptics.mediumTick());
  await ItineraryTrackingController.start(
    legs: buildDisplayLegs(itinerary.legs),
    fingerprint: ItineraryTrackingController.fingerprintFor(itinerary),
    initialPos: pos,
    startLegIndex: 0,
  );
  if (!context.mounted) return;

  await Navigator.of(
    context,
  ).push(CustomPageRoute(child: ItineraryMapScreen(itinerary: itinerary)));
}

/// Locates [boardingPlace] within the full trip's stop sequence — by stop
/// ID when available, otherwise by nearest coordinates (the departures/map
/// surfaces that feed this don't always carry a stop ID).
int? _findBoardingIndex(List<TripStop> stops, StopPlace boardingPlace) {
  final stopId = boardingPlace.stopId;
  if (stopId != null) {
    final byId = stops.indexWhere((s) => s.stopId == stopId);
    if (byId != -1) return byId;
  }

  int? bestIndex;
  double bestDistance = double.infinity;
  for (int i = 0; i < stops.length; i++) {
    final distance = coordinateDistanceInMeters(
      stops[i].lat,
      stops[i].lon,
      boardingPlace.lat,
      boardingPlace.lon,
    );
    if (distance < bestDistance) {
      bestDistance = distance;
      bestIndex = i;
    }
  }
  return bestIndex;
}

Future<LatLng?> _resolveCurrentPosition() async {
  try {
    final pos = await LocationService.currentPosition().timeout(
      const Duration(seconds: 5),
    );
    return LatLng(pos.latitude, pos.longitude);
  } catch (_) {
    try {
      final last = await LocationService.lastKnownPosition();
      if (last != null) return LatLng(last.latitude, last.longitude);
    } catch (_) {}
    return LocationService.loadLastLatLng();
  }
}
