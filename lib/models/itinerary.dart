import 'dart:developer' as developer;

import 'package:maplibre_gl/maplibre_gl.dart' show LatLng;

import '../utils/geo_utils.dart';
import '../utils/polyline_utils.dart';

/// The routing API's generic placeholder for a walk leg endpoint that isn't
/// a named GTFS stop (e.g. an arbitrary address or "my location").
bool _isPlaceholderEndpointName(String name) {
  final normalized = name.trim().toUpperCase();
  return normalized == 'START' || normalized == 'END';
}

/// Finds the stop in [sequence] matching [stopId] (preferred) or nearest to
/// ([lat], [lon]) otherwise — used to re-locate a leg's boarding/alighting
/// point within a freshly re-fetched full trip.
int? _matchStopIndex(
  List<TripStop> sequence,
  String? stopId,
  double lat,
  double lon,
) {
  if (stopId != null) {
    final byId = sequence.indexWhere((s) => s.stopId == stopId);
    if (byId != -1) return byId;
  }
  int? bestIndex;
  double bestDistance = double.infinity;
  for (int i = 0; i < sequence.length; i++) {
    final distance = coordinateDistanceInMeters(
      sequence[i].lat,
      sequence[i].lon,
      lat,
      lon,
    );
    if (distance < bestDistance) {
      bestDistance = distance;
      bestIndex = i;
    }
  }
  return bestIndex;
}

class FareInfo {
  final double amount;
  final String currency;

  FareInfo({required this.amount, required this.currency});

  factory FareInfo.fromJson(Map<String, dynamic> json) {
    return FareInfo(
      amount: json['amount']?.toDouble() ?? 0.0,
      currency: json['currency'] ?? '',
    );
  }
}

class TicketProduct {
  final String name;
  final double amount;
  final String currency;
  final String? fareMediaName;
  final String? fareMediaType;

  TicketProduct({
    required this.name,
    required this.amount,
    required this.currency,
    this.fareMediaName,
    this.fareMediaType,
  });

  factory TicketProduct.fromJson(Map<String, dynamic> json) {
    final media = json['media'];
    final Map<String, dynamic> mediaMap = media is Map<String, dynamic>
        ? media
        : {};
    return TicketProduct(
      name: json['name'] ?? '',
      amount: json['amount']?.toDouble() ?? 0.0,
      currency: json['currency'] ?? '',
      fareMediaName: mediaMap['fareMediaName'],
      fareMediaType: mediaMap['fareMediaType'],
    );
  }
}

class FareOption {
  final List<TicketProduct> products;

  FareOption({required this.products});

  factory FareOption.fromJson(List<dynamic> json) {
    return FareOption(
      products: json
          .whereType<Map<String, dynamic>>()
          .map((p) => TicketProduct.fromJson(p))
          .toList(),
    );
  }
}

class RouteBadge {
  final String name;
  final String? routeColor;
  final String? routeTextColor;

  RouteBadge({required this.name, this.routeColor, this.routeTextColor});
}

class FareLegInfo {
  final List<RouteBadge> routeBadges;
  final List<FareOption> options;

  /// A deep link straight to buying this fare, when the agency exposes one
  /// (GTFS `ticketUrls`) — preferred over [fareUrl] wherever both exist.
  final String? ticketUrl;

  /// The agency's general fare-information page (GTFS `agencyFareUrl`),
  /// shown only when there's no more specific [ticketUrl].
  final String? fareUrl;

  FareLegInfo({
    required this.routeBadges,
    required this.options,
    this.ticketUrl,
    this.fareUrl,
  });

  String get _optionsKey => options
      .map(
        (o) => o.products
            .map(
              (p) =>
                  '${p.name}|${p.amount}|${p.currency}|${p.fareMediaName}|${p.fareMediaType}',
            )
            .join(','),
      )
      .join(';');
}

class Alert {
  final String? cause;
  final String? causeDetail;
  final String? effect;
  final String? effectDetail;
  final String? url;
  final String? headerText;
  final String? descriptionText;
  final String? severityLevel;

  Alert({
    this.cause,
    this.causeDetail,
    this.effect,
    this.effectDetail,
    this.url,
    this.headerText,
    this.descriptionText,
    this.severityLevel,
  });

  factory Alert.fromJson(Map<String, dynamic> json) {
    return Alert(
      cause: json['cause'],
      causeDetail: json['causeDetail'],
      effect: json['effect'],
      effectDetail: json['effectDetail'],
      url: json['url'],
      headerText: json['headerText'],
      descriptionText: json['descriptionText'],
      severityLevel: json['severityLevel'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cause': cause,
      'causeDetail': causeDetail,
      'effect': effect,
      'effectDetail': effectDetail,
      'url': url,
      'headerText': headerText,
      'descriptionText': descriptionText,
      'severityLevel': severityLevel,
    };
  }
}

class IntermediateStop {
  final String name;
  final String? stopId;
  final double lat;
  final double lon;
  final DateTime? arrival;
  final DateTime? departure;
  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;
  final String? track;
  final String? scheduledTrack;
  final bool cancelled;
  final List<Alert> alerts;

  IntermediateStop({
    required this.name,
    this.stopId,
    required this.lat,
    required this.lon,
    this.arrival,
    this.departure,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.track,
    this.scheduledTrack,
    this.cancelled = false,
    this.alerts = const [],
  });

  factory IntermediateStop.fromJson(Map<String, dynamic> json) {
    return IntermediateStop(
      name: json['name'] ?? '',
      stopId: json['stopId'],
      lat: json['lat']?.toDouble() ?? 0.0,
      lon: json['lon']?.toDouble() ?? 0.0,
      arrival: json['arrival'] != null ? DateTime.parse(json['arrival']) : null,
      departure: json['departure'] != null
          ? DateTime.parse(json['departure'])
          : null,
      scheduledArrival: json['scheduledArrival'] != null
          ? DateTime.parse(json['scheduledArrival'])
          : null,
      scheduledDeparture: json['scheduledDeparture'] != null
          ? DateTime.parse(json['scheduledDeparture'])
          : null,
      track: json['track'],
      scheduledTrack: json['scheduledTrack'],
      cancelled: json['cancelled'] ?? false,
      alerts: json['alerts'] != null
          ? (json['alerts'] as List).map((a) => Alert.fromJson(a)).toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'stopId': stopId,
      'lat': lat,
      'lon': lon,
      'arrival': arrival?.toIso8601String(),
      'departure': departure?.toIso8601String(),
      'scheduledArrival': scheduledArrival?.toIso8601String(),
      'scheduledDeparture': scheduledDeparture?.toIso8601String(),
      'track': track,
      'scheduledTrack': scheduledTrack,
      'cancelled': cancelled,
      'alerts': alerts.map((a) => a.toJson()).toList(),
    };
  }
}

class EncodedPolyline {
  final String points;
  final int precision;
  final int length;

  EncodedPolyline({
    required this.points,
    required this.precision,
    required this.length,
  });

  factory EncodedPolyline.fromJson(Map<String, dynamic> json) {
    return EncodedPolyline(
      points: json['points'] ?? '',
      precision: json['precision'] ?? 5,
      length: json['length'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {'points': points, 'precision': precision, 'length': length};
  }
}

class Itinerary {
  final int duration;
  final DateTime startTime;
  final DateTime endTime;
  final int transfers;
  final List<Leg> legs;
  final bool isDirect;
  final FareInfo? fare;
  final List<FareLegInfo> ticketInfo;

  Itinerary({
    required this.duration,
    required this.startTime,
    required this.endTime,
    required this.transfers,
    required this.legs,
    this.isDirect = false,
    this.fare,
    this.ticketInfo = const [],
  });

  bool get hasTicketInfo => ticketInfo.isNotEmpty;

  /// Serializes the core fields needed to re-render this itinerary later
  /// (e.g. a saved trip snapshot). Deliberately omits [fare]/[ticketInfo],
  /// which have no JSON round-trip of their own and are decorative on the
  /// detail screen — it renders fine without them.
  Map<String, dynamic> toJson() {
    return {
      'duration': duration,
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'transfers': transfers,
      'legs': legs.map((leg) => leg.toJson()).toList(),
      'isDirect': isDirect,
    };
  }

  /// Returns a copy of this itinerary with [newLegs] substituted in,
  /// recomputing the fields derived from the leg list (e.g. after a
  /// real-time refresh updates individual legs).
  Itinerary withLegs(List<Leg> newLegs) {
    if (newLegs.isEmpty) return this;
    final transitLegCount = newLegs.where((l) => l.mode != 'WALK').length;
    return Itinerary(
      duration: newLegs.last.endTime
          .difference(newLegs.first.startTime)
          .inSeconds,
      startTime: newLegs.first.startTime,
      endTime: newLegs.last.endTime,
      transfers: transitLegCount > 0 ? transitLegCount - 1 : 0,
      legs: newLegs,
      isDirect: isDirect,
      fare: fare,
      ticketInfo: ticketInfo,
    );
  }

  /// Replaces a placeholder first/last leg endpoint name ("START"/"END",
  /// what the routing API returns for a walk leg whose endpoint isn't a
  /// named GTFS stop) with [fromLabel]/[toLabel] — the place the user
  /// actually searched for. No-ops wherever a label isn't available or the
  /// existing name isn't a placeholder, so it's safe to call unconditionally.
  Itinerary withResolvedEndpointNames({String? fromLabel, String? toLabel}) {
    if (legs.isEmpty) return this;
    final newLegs = List<Leg>.from(legs);

    final first = newLegs.first;
    if (fromLabel != null &&
        fromLabel.isNotEmpty &&
        _isPlaceholderEndpointName(first.fromName)) {
      newLegs[0] = first.withEndpointNames(fromName: fromLabel);
    }

    final last = newLegs.last;
    if (toLabel != null &&
        toLabel.isNotEmpty &&
        _isPlaceholderEndpointName(last.toName)) {
      newLegs[newLegs.length - 1] = last.withEndpointNames(toName: toLabel);
    }

    return withLegs(newLegs);
  }

  double get walkingDistance {
    double totalDistance = 0.0;
    for (final leg in legs) {
      if (leg.mode == 'WALK' && leg.distance != null) {
        totalDistance += leg.distance!;
      }
    }
    return totalDistance;
  }

  // maybe give the user control over this?
  int get calories {
    final walkingKm = walkingDistance / 1000;
    return (walkingKm * 50).round();
  }

  int get alertsCount {
    int count = 0;
    for (final leg in legs) {
      count += leg.alerts.length;
      for (final stop in leg.intermediateStops) {
        count += stop.alerts.length;
      }
    }
    return count;
  }

  factory Itinerary.fromJson(
    Map<String, dynamic> json, {
    bool isDirect = false,
  }) {
    final legs = (json['legs'] as List)
        .map((leg) => Leg.fromJson(leg))
        .toList();

    FareInfo? fare;
    var ticketInfo = <FareLegInfo>[];
    if (json['fareTransfers'] != null &&
        (json['fareTransfers'] as List).isNotEmpty) {
      final fareTransfer = (json['fareTransfers'] as List).first;
      if (fareTransfer['transferProducts'] != null &&
          (fareTransfer['transferProducts'] as List).isNotEmpty) {
        fare = FareInfo.fromJson(
          (fareTransfer['transferProducts'] as List).first,
        );
      }

      try {
        final routeBadgesByFareLeg = <String, List<RouteBadge>>{};
        // Prefer a leg's own ticketing deep link over its agency's general
        // fare page; both are keyed the same way as the route badges above
        // so they land on the right merged FareLegInfo below.
        final ticketUrlByFareLeg = <String, String>{};
        final fareUrlByFareLeg = <String, String>{};
        for (final leg in legs) {
          if (leg.fareTransferIndex == null ||
              leg.effectiveFareLegIndex == null) {
            continue;
          }
          final key = '${leg.fareTransferIndex}:${leg.effectiveFareLegIndex}';
          if (leg.ticketUrl != null && !ticketUrlByFareLeg.containsKey(key)) {
            ticketUrlByFareLeg[key] = leg.ticketUrl!;
          }
          if (leg.agencyFareUrl != null && !fareUrlByFareLeg.containsKey(key)) {
            fareUrlByFareLeg[key] = leg.agencyFareUrl!;
          }

          final name = leg.routeShortName ?? leg.displayName;
          if (name == null || name.isEmpty) continue;
          final badges = routeBadgesByFareLeg.putIfAbsent(key, () => []);
          if (!badges.any((b) => b.name == name)) {
            badges.add(
              RouteBadge(
                name: name,
                routeColor: leg.routeColor,
                routeTextColor: leg.routeTextColor,
              ),
            );
          }
        }

        final rawTicketInfo = <FareLegInfo>[];
        final transfers = json['fareTransfers'] as List;
        for (var t = 0; t < transfers.length; t++) {
          final legProducts = transfers[t]['effectiveFareLegProducts'];
          if (legProducts is! List) continue;
          for (var i = 0; i < legProducts.length; i++) {
            final legOptions = legProducts[i];
            if (legOptions is! List) continue;
            final options = legOptions
                .whereType<List<dynamic>>()
                .map((o) => FareOption.fromJson(o))
                .where((o) => o.products.isNotEmpty)
                .toList();
            if (options.isEmpty) continue;
            final key = '$t:$i';
            rawTicketInfo.add(
              FareLegInfo(
                routeBadges: routeBadgesByFareLeg[key] ?? const [],
                options: options,
                ticketUrl: ticketUrlByFareLeg[key],
                fareUrl: fareUrlByFareLeg[key],
              ),
            );
          }
        }

        // Merge fare legs that share identical ticket options.
        final mergedByKey = <String, FareLegInfo>{};
        final order = <String>[];
        for (final entry in rawTicketInfo) {
          final key = entry._optionsKey;
          final existing = mergedByKey[key];
          if (existing == null) {
            mergedByKey[key] = entry;
            order.add(key);
          } else {
            final combinedBadges = [...existing.routeBadges];
            for (final badge in entry.routeBadges) {
              if (!combinedBadges.any((b) => b.name == badge.name)) {
                combinedBadges.add(badge);
              }
            }
            mergedByKey[key] = FareLegInfo(
              routeBadges: combinedBadges,
              options: existing.options,
              ticketUrl: existing.ticketUrl ?? entry.ticketUrl,
              fareUrl: existing.fareUrl ?? entry.fareUrl,
            );
          }
        }
        ticketInfo = order.map((key) => mergedByKey[key]!).toList();
      } catch (e, stackTrace) {
        developer.log(
          'Error parsing ticket info',
          name: 'Itinerary',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    return Itinerary(
      duration: json['duration'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      transfers: json['transfers'] ?? 0,
      legs: legs,
      isDirect: isDirect,
      fare: fare,
      ticketInfo: ticketInfo,
    );
  }
}

/// A single stop along a leg's full run, used by [Leg.fullStopSequence] /
/// [Leg.sliceBetween] to locate and slice out a boarding→alighting range.
class TripStop {
  final String name;
  final String? stopId;
  final double lat;
  final double lon;
  final DateTime? arrival;
  final DateTime? departure;
  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;
  final String? track;

  const TripStop({
    required this.name,
    this.stopId,
    required this.lat,
    required this.lon,
    this.arrival,
    this.departure,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.track,
  });
}

class Leg {
  final String mode;
  final String fromName;
  final String toName;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? scheduledStartTime;
  final DateTime? scheduledEndTime;
  final int duration;
  final double? distance;
  final String? routeShortName;
  final String? routeLongName;
  final String? displayName;
  final String? headsign;
  final String? routeColor;
  final String? routeTextColor;
  final int? routeType;
  final String? agencyName;
  final String? agencyUrl;
  final String? agencyId;
  final String? tripId;
  final String? tripShortName;
  final bool realTime;
  final bool cancelled;
  final String? fromTrack;
  final String? toTrack;
  final String? fromScheduledTrack;
  final String? toScheduledTrack;
  final String? fromStopId;
  final String? toStopId;
  final double fromLat;
  final double fromLon;
  final double toLat;
  final double toLon;
  final List<IntermediateStop> intermediateStops;
  final List<Alert> alerts;
  final EncodedPolyline? legGeometry;
  final bool interlineWithPreviousLeg;
  final int? fareTransferIndex;
  final int? effectiveFareLegIndex;

  /// A deep link straight to buying this leg's fare (GTFS `ticketUrls.web`).
  final String? ticketUrl;

  /// The agency's general fare-information page (GTFS `agencyFareUrl`).
  final String? agencyFareUrl;

  Leg({
    required this.mode,
    required this.fromName,
    required this.toName,
    required this.startTime,
    required this.endTime,
    this.scheduledStartTime,
    this.scheduledEndTime,
    required this.duration,
    this.distance,
    this.routeShortName,
    this.routeLongName,
    this.displayName,
    this.headsign,
    this.routeColor,
    this.routeTextColor,
    this.routeType,
    this.agencyName,
    this.agencyUrl,
    this.agencyId,
    this.tripId,
    this.tripShortName,
    this.realTime = false,
    this.cancelled = false,
    this.fromTrack,
    this.toTrack,
    this.fromScheduledTrack,
    this.toScheduledTrack,
    this.fromStopId,
    this.toStopId,
    required this.fromLat,
    required this.fromLon,
    required this.toLat,
    required this.toLon,
    this.intermediateStops = const [],
    this.alerts = const [],
    this.legGeometry,
    this.interlineWithPreviousLeg = false,
    this.fareTransferIndex,
    this.effectiveFareLegIndex,
    this.ticketUrl,
    this.agencyFareUrl,
  });

  /// Returns a copy of this leg with the real-time fields (times, delay,
  /// cancellation, track, intermediate stops, alerts) refreshed from
  /// [fresh], while keeping itinerary-specific context (fare indices,
  /// geometry) from this leg. [fresh] is typically a full re-fetch of the
  /// same trip and may cover more stops than this leg does (e.g. this leg
  /// only boards partway through); it's narrowed down to this leg's own
  /// boarding→alighting range first, so a refresh can't silently expand a
  /// partial-trip leg into the whole trip.
  Leg withRealTimeFrom(Leg fresh) {
    final matched = fresh._slicedToMatch(this);
    return Leg(
      mode: mode,
      fromName: fromName,
      toName: toName,
      startTime: matched.startTime,
      endTime: matched.endTime,
      scheduledStartTime: matched.scheduledStartTime ?? scheduledStartTime,
      scheduledEndTime: matched.scheduledEndTime ?? scheduledEndTime,
      duration: matched.duration,
      distance: distance,
      routeShortName: routeShortName,
      routeLongName: routeLongName,
      displayName: displayName,
      headsign: headsign,
      routeColor: routeColor,
      routeTextColor: routeTextColor,
      routeType: routeType,
      agencyName: agencyName,
      agencyUrl: agencyUrl,
      agencyId: agencyId,
      tripId: tripId,
      tripShortName: tripShortName,
      realTime: matched.realTime,
      cancelled: matched.cancelled,
      fromTrack: matched.fromTrack ?? fromTrack,
      toTrack: matched.toTrack ?? toTrack,
      fromScheduledTrack: fromScheduledTrack,
      toScheduledTrack: toScheduledTrack,
      fromStopId: fromStopId,
      toStopId: toStopId,
      fromLat: fromLat,
      fromLon: fromLon,
      toLat: toLat,
      toLon: toLon,
      intermediateStops: matched.intermediateStops.isNotEmpty
          ? matched.intermediateStops
          : intermediateStops,
      alerts: matched.alerts.isNotEmpty ? matched.alerts : alerts,
      legGeometry: legGeometry,
      interlineWithPreviousLeg: interlineWithPreviousLeg,
      fareTransferIndex: fareTransferIndex,
      effectiveFareLegIndex: effectiveFareLegIndex,
      ticketUrl: matched.ticketUrl ?? ticketUrl,
      agencyFareUrl: matched.agencyFareUrl ?? agencyFareUrl,
    );
  }

  /// Narrows this leg (assumed to be the same trip as [original], but
  /// possibly covering more of it — e.g. a full trip re-fetched for a
  /// real-time refresh) down to just [original]'s own boarding→alighting
  /// range. Falls back to itself unsliced if the endpoints can't be
  /// matched (e.g. it turns out to be a genuinely different trip).
  Leg _slicedToMatch(Leg original) {
    final sequence = fullStopSequence;
    if (sequence.length < 2) return this;
    final boardingIndex = _matchStopIndex(
      sequence,
      original.fromStopId,
      original.fromLat,
      original.fromLon,
    );
    final alightingIndex = _matchStopIndex(
      sequence,
      original.toStopId,
      original.toLat,
      original.toLon,
    );
    if (boardingIndex == null ||
        alightingIndex == null ||
        boardingIndex >= alightingIndex) {
      return this;
    }
    return sliceBetween(boardingIndex, alightingIndex);
  }

  /// Returns a copy with [fromName]/[toName] overridden — used to replace a
  /// placeholder endpoint name (e.g. "START"/"END", returned by the routing
  /// API for a walk leg whose endpoint isn't a named GTFS stop) with the
  /// place name the user actually searched for.
  Leg withEndpointNames({String? fromName, String? toName}) {
    return Leg(
      mode: mode,
      fromName: fromName ?? this.fromName,
      toName: toName ?? this.toName,
      startTime: startTime,
      endTime: endTime,
      scheduledStartTime: scheduledStartTime,
      scheduledEndTime: scheduledEndTime,
      duration: duration,
      distance: distance,
      routeShortName: routeShortName,
      routeLongName: routeLongName,
      displayName: displayName,
      headsign: headsign,
      routeColor: routeColor,
      routeTextColor: routeTextColor,
      routeType: routeType,
      agencyName: agencyName,
      agencyUrl: agencyUrl,
      agencyId: agencyId,
      tripId: tripId,
      tripShortName: tripShortName,
      realTime: realTime,
      cancelled: cancelled,
      fromTrack: fromTrack,
      toTrack: toTrack,
      fromScheduledTrack: fromScheduledTrack,
      toScheduledTrack: toScheduledTrack,
      fromStopId: fromStopId,
      toStopId: toStopId,
      fromLat: fromLat,
      fromLon: fromLon,
      toLat: toLat,
      toLon: toLon,
      intermediateStops: intermediateStops,
      alerts: alerts,
      legGeometry: legGeometry,
      interlineWithPreviousLeg: interlineWithPreviousLeg,
      fareTransferIndex: fareTransferIndex,
      effectiveFareLegIndex: effectiveFareLegIndex,
      ticketUrl: ticketUrl,
      agencyFareUrl: agencyFareUrl,
    );
  }

  /// Every stop this leg passes through, from origin to terminus, as a flat
  /// ordered list — its own endpoints plus its intermediate stops. Used for
  /// ad-hoc tracking (started by picking a stop directly rather than
  /// searching an itinerary), where the leg fetched from [TripDetailsService]
  /// covers the trip's full run and needs narrowing to the boarding→alighting
  /// sub-range the user actually picked.
  List<TripStop> get fullStopSequence {
    return [
      TripStop(
        name: fromName,
        stopId: fromStopId,
        lat: fromLat,
        lon: fromLon,
        arrival: startTime,
        departure: startTime,
        scheduledArrival: scheduledStartTime,
        scheduledDeparture: scheduledStartTime,
        track: fromTrack,
      ),
      for (final stop in intermediateStops)
        TripStop(
          name: stop.name,
          stopId: stop.stopId,
          lat: stop.lat,
          lon: stop.lon,
          arrival: stop.arrival,
          departure: stop.departure,
          scheduledArrival: stop.scheduledArrival,
          scheduledDeparture: stop.scheduledDeparture,
          track: stop.track,
        ),
      TripStop(
        name: toName,
        stopId: toStopId,
        lat: toLat,
        lon: toLon,
        arrival: endTime,
        departure: endTime,
        scheduledArrival: scheduledEndTime,
        scheduledDeparture: scheduledEndTime,
        track: toTrack,
      ),
    ];
  }

  /// Builds a synthetic leg covering only the [boardingIndex]→[alightingIndex]
  /// sub-range of [fullStopSequence] — route/trip metadata (route name,
  /// colors, agency, tripId, ...) is copied as-is; endpoints, times,
  /// intermediate stops and [legGeometry] are all narrowed to that range, so
  /// the map draws the real route shape rather than a straight line between
  /// the new endpoints.
  Leg sliceBetween(int boardingIndex, int alightingIndex) {
    final sequence = fullStopSequence;
    final boarding = sequence[boardingIndex];
    final alighting = sequence[alightingIndex];
    final between = sequence.sublist(boardingIndex + 1, alightingIndex);
    final legStartTime = boarding.departure ?? boarding.arrival ?? startTime;
    final legEndTime = alighting.arrival ?? alighting.departure ?? endTime;

    return Leg(
      mode: mode,
      fromName: boarding.name,
      toName: alighting.name,
      startTime: legStartTime,
      endTime: legEndTime,
      scheduledStartTime: boarding.scheduledDeparture ?? boarding.scheduledArrival,
      scheduledEndTime: alighting.scheduledArrival ?? alighting.scheduledDeparture,
      duration: legEndTime.difference(legStartTime).inSeconds,
      routeShortName: routeShortName,
      routeLongName: routeLongName,
      displayName: displayName,
      headsign: headsign,
      routeColor: routeColor,
      routeTextColor: routeTextColor,
      routeType: routeType,
      agencyName: agencyName,
      agencyUrl: agencyUrl,
      agencyId: agencyId,
      tripId: tripId,
      tripShortName: tripShortName,
      realTime: realTime,
      cancelled: cancelled,
      fromTrack: boarding.track,
      toTrack: alighting.track,
      fromStopId: boarding.stopId,
      toStopId: alighting.stopId,
      fromLat: boarding.lat,
      fromLon: boarding.lon,
      toLat: alighting.lat,
      toLon: alighting.lon,
      intermediateStops: [
        for (final stop in between)
          IntermediateStop(
            name: stop.name,
            stopId: stop.stopId,
            lat: stop.lat,
            lon: stop.lon,
            arrival: stop.arrival,
            departure: stop.departure,
            scheduledArrival: stop.scheduledArrival,
            scheduledDeparture: stop.scheduledDeparture,
            track: stop.track,
          ),
      ],
      alerts: alerts,
      legGeometry: _slicedGeometry(boarding, alighting),
      interlineWithPreviousLeg: false,
      ticketUrl: ticketUrl,
      agencyFareUrl: agencyFareUrl,
    );
  }

  /// Narrows this leg's route shape down to just the boarding→alighting
  /// sub-range, by finding the polyline points nearest each stop and
  /// keeping only what's between them. Returns null (map falls back to a
  /// straight line) if there's no geometry to slice, or if the nearest
  /// points can't be resolved into a sensible sub-range.
  EncodedPolyline? _slicedGeometry(TripStop boarding, TripStop alighting) {
    final geometry = legGeometry;
    if (geometry == null || geometry.points.isEmpty) return null;

    List<LatLng> points;
    try {
      points = decodePolyline(geometry.points, geometry.precision);
    } catch (_) {
      return null;
    }
    if (points.length < 2) return null;

    final startIndex = _nearestPolylinePointIndex(
      points,
      boarding.lat,
      boarding.lon,
    );
    final endIndex = _nearestPolylinePointIndex(
      points,
      alighting.lat,
      alighting.lon,
    );
    if (startIndex >= endIndex) return null;

    final sliced = points.sublist(startIndex, endIndex + 1);
    return EncodedPolyline(
      points: encodePolyline(sliced, geometry.precision),
      precision: geometry.precision,
      length: sliced.length,
    );
  }

  int _nearestPolylinePointIndex(List<LatLng> points, double lat, double lon) {
    int bestIndex = 0;
    double bestDistance = double.infinity;
    for (int i = 0; i < points.length; i++) {
      final distance = coordinateDistanceInMeters(
        points[i].latitude,
        points[i].longitude,
        lat,
        lon,
      );
      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  factory Leg.fromJson(Map<String, dynamic> json) {
    try {
      final from = json['from'];
      final to = json['to'];

      final Map<String, dynamic> fromMap = from is Map<String, dynamic>
          ? from
          : {};
      final Map<String, dynamic> toMap = to is Map<String, dynamic> ? to : {};

      List<IntermediateStop> intermediateStops = [];
      try {
        if (json['intermediateStops'] is List) {
          intermediateStops = (json['intermediateStops'] as List)
              .map((s) {
                try {
                  return IntermediateStop.fromJson(s);
                } catch (_) {
                  return null;
                }
              })
              .whereType<IntermediateStop>()
              .toList();
        }
      } catch (_) {}

      List<Alert> alerts = [];
      try {
        if (json['alerts'] is List) {
          alerts = (json['alerts'] as List)
              .map((a) {
                try {
                  return Alert.fromJson(a);
                } catch (_) {
                  return null;
                }
              })
              .whereType<Alert>()
              .toList();
        }
      } catch (_) {}

      EncodedPolyline? legGeometry;
      try {
        if (json['legGeometry'] is Map &&
            (json['legGeometry'] as Map).isNotEmpty) {
          legGeometry = EncodedPolyline.fromJson(json['legGeometry']);
        }
      } catch (e, stackTrace) {
        developer.log(
          'Error parsing legGeometry',
          name: 'Itinerary',
          error: e,
          stackTrace: stackTrace,
        );
      }

      return Leg(
        mode: json['mode'] ?? 'WALK',
        fromName: fromMap['name'] ?? '',
        toName: toMap['name'] ?? '',
        startTime: DateTime.parse(json['startTime']),
        endTime: DateTime.parse(json['endTime']),
        scheduledStartTime: json['scheduledStartTime'] != null
            ? DateTime.parse(json['scheduledStartTime'])
            : null,
        scheduledEndTime: json['scheduledEndTime'] != null
            ? DateTime.parse(json['scheduledEndTime'])
            : null,
        duration: json['duration'] ?? 0,
        distance: json['distance']?.toDouble(),
        routeShortName: json['routeShortName'],
        routeLongName: json['routeLongName'],
        displayName: json['displayName'],
        headsign: json['headsign'],
        routeColor: json['routeColor'],
        routeTextColor: json['routeTextColor'],
        routeType: json['routeType'],
        agencyName: json['agencyName'],
        agencyUrl: json['agencyUrl'],
        agencyId: json['agencyId'],
        tripId: json['tripId'],
        tripShortName: json['tripShortName'],
        realTime: json['realTime'] ?? false,
        cancelled: json['cancelled'] ?? false,
        fromTrack: fromMap['track'],
        toTrack: toMap['track'],
        fromScheduledTrack: fromMap['scheduledTrack'],
        toScheduledTrack: toMap['scheduledTrack'],
        fromStopId: fromMap['stopId'],
        toStopId: toMap['stopId'],
        fromLat: fromMap['lat']?.toDouble() ?? 0.0,
        fromLon: fromMap['lon']?.toDouble() ?? 0.0,
        toLat: toMap['lat']?.toDouble() ?? 0.0,
        toLon: toMap['lon']?.toDouble() ?? 0.0,
        intermediateStops: intermediateStops,
        alerts: alerts,
        legGeometry: legGeometry,
        interlineWithPreviousLeg: json['interlineWithPreviousLeg'] ?? false,
        fareTransferIndex: json['fareTransferIndex'],
        effectiveFareLegIndex: json['effectiveFareLegIndex'],
        ticketUrl: (json['ticketUrls'] is Map)
            ? (json['ticketUrls'] as Map)['web'] as String?
            : null,
        agencyFareUrl: json['agencyFareUrl'],
      );
    } catch (e, stackTrace) {
      developer.log(
        'Error parsing Leg',
        name: 'Itinerary',
        error: e,
        stackTrace: stackTrace,
      );
      developer.log('Leg JSON: $json', name: 'Itinerary');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'from': {
        'name': fromName,
        'track': fromTrack,
        'scheduledTrack': fromScheduledTrack,
        'lat': fromLat,
        'lon': fromLon,
      },
      'to': {
        'name': toName,
        'track': toTrack,
        'scheduledTrack': toScheduledTrack,
        'lat': toLat,
        'lon': toLon,
      },
      'startTime': startTime.toIso8601String(),
      'endTime': endTime.toIso8601String(),
      'scheduledStartTime': scheduledStartTime?.toIso8601String(),
      'scheduledEndTime': scheduledEndTime?.toIso8601String(),
      'duration': duration,
      'distance': distance,
      'routeShortName': routeShortName,
      'routeLongName': routeLongName,
      'displayName': displayName,
      'headsign': headsign,
      'routeColor': routeColor,
      'routeTextColor': routeTextColor,
      'routeType': routeType,
      'agencyName': agencyName,
      'agencyUrl': agencyUrl,
      'agencyId': agencyId,
      'tripId': tripId,
      'tripShortName': tripShortName,
      'realTime': realTime,
      'cancelled': cancelled,
      'intermediateStops': intermediateStops.map((s) => s.toJson()).toList(),
      'alerts': alerts.map((a) => a.toJson()).toList(),
      'legGeometry': legGeometry?.toJson(),
      'interlineWithPreviousLeg': interlineWithPreviousLeg,
      'fareTransferIndex': fareTransferIndex,
      'effectiveFareLegIndex': effectiveFareLegIndex,
      'ticketUrls': ticketUrl == null ? null : {'web': ticketUrl},
      'agencyFareUrl': agencyFareUrl,
    };
  }
}
