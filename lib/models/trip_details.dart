import '../models/itinerary.dart' show Alert, EncodedPolyline;

class TripDetailsResponse {
  final int duration;
  final DateTime startTime;
  final DateTime endTime;
  final int transfers;
  final List<TripLeg> legs;

  const TripDetailsResponse({
    required this.duration,
    required this.startTime,
    required this.endTime,
    required this.transfers,
    required this.legs,
  });

  factory TripDetailsResponse.fromJson(Map<String, dynamic> json) {
    return TripDetailsResponse(
      duration: json['duration'] as int,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      transfers: json['transfers'] as int,
      legs: (json['legs'] as List)
          .map((item) => TripLeg.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

class TripLeg {
  final String mode;
  final TripPlace from;
  final TripPlace to;
  final int duration;
  final DateTime startTime;
  final DateTime endTime;
  final DateTime? scheduledStartTime;
  final DateTime? scheduledEndTime;
  final bool realTime;
  final bool? scheduled;
  final double? distance;
  final bool? interlineWithPreviousLeg;
  final String? headsign;
  final TripPlace? tripTo;
  final String? routeColor;
  final String? routeTextColor;
  final int? routeType;
  final String? agencyName;
  final String? agencyUrl;
  final String? agencyId;
  final String? tripId;
  final String? routeShortName;
  final String? routeLongName;
  final String? tripShortName;
  final String? displayName;
  final bool? cancelled;
  final String? source;
  final List<TripPlace> intermediateStops;
  final List<Alert> alerts;
  final EncodedPolyline? legGeometry;

  const TripLeg({
    required this.mode,
    required this.from,
    required this.to,
    required this.duration,
    required this.startTime,
    required this.endTime,
    this.scheduledStartTime,
    this.scheduledEndTime,
    required this.realTime,
    this.scheduled,
    this.distance,
    this.interlineWithPreviousLeg,
    this.headsign,
    this.tripTo,
    this.routeColor,
    this.routeTextColor,
    this.routeType,
    this.agencyName,
    this.agencyUrl,
    this.agencyId,
    this.tripId,
    this.routeShortName,
    this.routeLongName,
    this.tripShortName,
    this.displayName,
    this.cancelled,
    this.source,
    this.intermediateStops = const [],
    this.alerts = const [],
    this.legGeometry,
  });

  factory TripLeg.fromJson(Map<String, dynamic> json) {
    return TripLeg(
      mode: json['mode'] as String,
      from: TripPlace.fromJson(json['from'] as Map<String, dynamic>),
      to: TripPlace.fromJson(json['to'] as Map<String, dynamic>),
      duration: json['duration'] as int,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      scheduledStartTime: json['scheduledStartTime'] != null
          ? DateTime.parse(json['scheduledStartTime'] as String)
          : null,
      scheduledEndTime: json['scheduledEndTime'] != null
          ? DateTime.parse(json['scheduledEndTime'] as String)
          : null,
      realTime: json['realTime'] as bool,
      scheduled: json['scheduled'] as bool?,
      distance: (json['distance'] as num?)?.toDouble(),
      interlineWithPreviousLeg: json['interlineWithPreviousLeg'] as bool?,
      headsign: json['headsign'] as String?,
      tripTo: json['tripTo'] != null
          ? TripPlace.fromJson(json['tripTo'] as Map<String, dynamic>)
          : null,
      routeColor: json['routeColor'] as String?,
      routeTextColor: json['routeTextColor'] as String?,
      routeType: json['routeType'] as int?,
      agencyName: json['agencyName'] as String?,
      agencyUrl: json['agencyUrl'] as String?,
      agencyId: json['agencyId'] as String?,
      tripId: json['tripId'] as String?,
      routeShortName: json['routeShortName'] as String?,
      routeLongName: json['routeLongName'] as String?,
      tripShortName: json['tripShortName'] as String?,
      displayName: json['displayName'] as String?,
      cancelled: json['cancelled'] as bool?,
      source: json['source'] as String?,
      intermediateStops: (json['intermediateStops'] as List<dynamic>?)
              ?.map((item) => TripPlace.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      alerts: (json['alerts'] as List<dynamic>?)
              ?.map((item) => Alert.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
      legGeometry: json['legGeometry'] != null
          ? EncodedPolyline.fromJson(json['legGeometry'] as Map<String, dynamic>)
          : null,
    );
  }
}

class TripPlace {
  final String name;
  final String? stopId;
  final double? importance;
  final double lat;
  final double lon;
  final double? level;
  final String? tz;
  final DateTime? arrival;
  final DateTime? departure;
  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;
  final String? scheduledTrack;
  final String? track;
  final String? description;
  final String? vertexType;
  final String? pickupType;
  final String? dropoffType;
  final bool? cancelled;
  final List<Alert> alerts;

  const TripPlace({
    required this.name,
    this.stopId,
    this.importance,
    required this.lat,
    required this.lon,
    this.level,
    this.tz,
    this.arrival,
    this.departure,
    this.scheduledArrival,
    this.scheduledDeparture,
    this.scheduledTrack,
    this.track,
    this.description,
    this.vertexType,
    this.pickupType,
    this.dropoffType,
    this.cancelled,
    this.alerts = const [],
  });

  factory TripPlace.fromJson(Map<String, dynamic> json) {
    return TripPlace(
      name: json['name'] as String,
      stopId: json['stopId'] as String?,
      importance: (json['importance'] as num?)?.toDouble(),
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      level: (json['level'] as num?)?.toDouble(),
      tz: json['tz'] as String?,
      arrival: json['arrival'] != null
          ? DateTime.parse(json['arrival'] as String)
          : null,
      departure: json['departure'] != null
          ? DateTime.parse(json['departure'] as String)
          : null,
      scheduledArrival: json['scheduledArrival'] != null
          ? DateTime.parse(json['scheduledArrival'] as String)
          : null,
      scheduledDeparture: json['scheduledDeparture'] != null
          ? DateTime.parse(json['scheduledDeparture'] as String)
          : null,
      scheduledTrack: json['scheduledTrack'] as String?,
      track: json['track'] as String?,
      description: json['description'] as String?,
      vertexType: json['vertexType'] as String?,
      pickupType: json['pickupType'] as String?,
      dropoffType: json['dropoffType'] as String?,
      cancelled: json['cancelled'] as bool?,
      alerts: (json['alerts'] as List<dynamic>?)
              ?.map((item) => Alert.fromJson(item as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
