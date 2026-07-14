import 'dart:developer' as developer;

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

  FareLegInfo({required this.routeBadges, required this.options});

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
        for (final leg in legs) {
          if (leg.fareTransferIndex == null ||
              leg.effectiveFareLegIndex == null) {
            continue;
          }
          final name = leg.routeShortName ?? leg.displayName;
          if (name == null || name.isEmpty) continue;
          final key = '${leg.fareTransferIndex}:${leg.effectiveFareLegIndex}';
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
            rawTicketInfo.add(
              FareLegInfo(
                routeBadges: routeBadgesByFareLeg['$t:$i'] ?? const [],
                options: options,
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
  });

  /// Returns a copy of this leg with the real-time fields (times, delay,
  /// cancellation, track, intermediate stops, alerts) refreshed from
  /// [fresh], while keeping itinerary-specific context (fare indices,
  /// geometry) from this leg.
  Leg withRealTimeFrom(Leg fresh) {
    return Leg(
      mode: mode,
      fromName: fromName,
      toName: toName,
      startTime: fresh.startTime,
      endTime: fresh.endTime,
      scheduledStartTime: fresh.scheduledStartTime ?? scheduledStartTime,
      scheduledEndTime: fresh.scheduledEndTime ?? scheduledEndTime,
      duration: fresh.duration,
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
      realTime: fresh.realTime,
      cancelled: fresh.cancelled,
      fromTrack: fresh.fromTrack ?? fromTrack,
      toTrack: fresh.toTrack ?? toTrack,
      fromScheduledTrack: fromScheduledTrack,
      toScheduledTrack: toScheduledTrack,
      fromStopId: fromStopId,
      toStopId: toStopId,
      fromLat: fromLat,
      fromLon: fromLon,
      toLat: toLat,
      toLon: toLon,
      intermediateStops: fresh.intermediateStops.isNotEmpty
          ? fresh.intermediateStops
          : intermediateStops,
      alerts: fresh.alerts.isNotEmpty ? fresh.alerts : alerts,
      legGeometry: legGeometry,
      interlineWithPreviousLeg: interlineWithPreviousLeg,
      fareTransferIndex: fareTransferIndex,
      effectiveFareLegIndex: effectiveFareLegIndex,
    );
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
}
