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

  Itinerary({
    required this.duration,
    required this.startTime,
    required this.endTime,
    required this.transfers,
    required this.legs,
    this.isDirect = false,
    this.fare,
  });

  // Calculate total walking distance in meters
  double get walkingDistance {
    double totalDistance = 0.0;
    for (final leg in legs) {
      if (leg.mode == 'WALK' && leg.distance != null) {
        totalDistance += leg.distance!;
      }
    }
    return totalDistance;
  }

  // Calculate calories burned from walking
  // Average: ~50 calories per km of walking
  int get calories {
    final walkingKm = walkingDistance / 1000;
    return (walkingKm * 50).round();
  }

  // Count total alerts across all legs
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
    // Extract fare from fareTransfers if available
    FareInfo? fare;
    if (json['fareTransfers'] != null &&
        (json['fareTransfers'] as List).isNotEmpty) {
      final fareTransfer = (json['fareTransfers'] as List).first;
      if (fareTransfer['transferProducts'] != null &&
          (fareTransfer['transferProducts'] as List).isNotEmpty) {
        fare = FareInfo.fromJson(
          (fareTransfer['transferProducts'] as List).first,
        );
      }
    }

    return Itinerary(
      duration: json['duration'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      transfers: json['transfers'] ?? 0,
      legs: (json['legs'] as List).map((leg) => Leg.fromJson(leg)).toList(),
      isDirect: isDirect,
      fare: fare,
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
  final double? distance; // Distance in meters
  final String? routeShortName;
  final String? routeLongName;
  final String? displayName;
  final String? headsign;
  // Hex color strings like "#FF0000" for UI styling.
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
  final double fromLat;
  final double fromLon;
  final double toLat;
  final double toLon;
  final List<IntermediateStop> intermediateStops;
  final List<Alert> alerts;
  final EncodedPolyline? legGeometry;
  final bool interlineWithPreviousLeg;

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
    required this.fromLat,
    required this.fromLon,
    required this.toLat,
    required this.toLon,
    this.intermediateStops = const [],
    this.alerts = const [],
    this.legGeometry,
    this.interlineWithPreviousLeg = false,
  });

  factory Leg.fromJson(Map<String, dynamic> json) {
    try {
      final from = json['from'];
      final to = json['to'];

      final Map<String, dynamic> fromMap = from is Map<String, dynamic>
          ? from
          : {};
      final Map<String, dynamic> toMap = to is Map<String, dynamic> ? to : {};

      // Parse intermediate stops safely
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

      // Parse alerts safely
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

      // Parse leg geometry safely
      EncodedPolyline? legGeometry;
      try {
        if (json['legGeometry'] is Map &&
            (json['legGeometry'] as Map).isNotEmpty) {
          legGeometry = EncodedPolyline.fromJson(json['legGeometry']);
        }
      } catch (e) {
        print('Error parsing legGeometry: $e');
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
        fromLat: fromMap['lat']?.toDouble() ?? 0.0,
        fromLon: fromMap['lon']?.toDouble() ?? 0.0,
        toLat: toMap['lat']?.toDouble() ?? 0.0,
        toLon: toMap['lon']?.toDouble() ?? 0.0,
        intermediateStops: intermediateStops,
        alerts: alerts,
        legGeometry: legGeometry,
        interlineWithPreviousLeg: json['interlineWithPreviousLeg'] ?? false,
      );
    } catch (e) {
      print('Error parsing Leg: $e');
      print('Leg JSON: $json');
      rethrow;
    }
  }
}
