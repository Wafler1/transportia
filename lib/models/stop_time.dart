class StopTimesResponse {
  final List<StopTime> stopTimes;
  final StopPlace place;
  final String? previousPageCursor;
  final String? nextPageCursor;

  const StopTimesResponse({
    required this.stopTimes,
    required this.place,
    this.previousPageCursor,
    this.nextPageCursor,
  });

  factory StopTimesResponse.fromJson(Map<String, dynamic> json) {
    return StopTimesResponse(
      stopTimes: (json['stopTimes'] as List)
          .map((item) => StopTime.fromJson(item as Map<String, dynamic>))
          .toList(),
      place: StopPlace.fromJson(json['place'] as Map<String, dynamic>),
      previousPageCursor: json['previousPageCursor'] as String?,
      nextPageCursor: json['nextPageCursor'] as String?,
    );
  }
}

class StopTime {
  final StopPlace place;
  final String mode;
  final bool realTime;
  final String headsign;
  final StopPlace? tripTo;
  final String agencyId;
  final String agencyName;
  final String? agencyUrl;
  final String? routeColor;
  final String? routeTextColor;
  final String tripId;
  final int routeType;
  final String routeShortName;
  final String routeLongName;
  final String displayName;
  final bool cancelled;
  final bool tripCancelled;

  const StopTime({
    required this.place,
    required this.mode,
    required this.realTime,
    required this.headsign,
    this.tripTo,
    required this.agencyId,
    required this.agencyName,
    this.agencyUrl,
    this.routeColor,
    this.routeTextColor,
    required this.tripId,
    required this.routeType,
    required this.routeShortName,
    required this.routeLongName,
    required this.displayName,
    required this.cancelled,
    required this.tripCancelled,
  });

  factory StopTime.fromJson(Map<String, dynamic> json) {
    return StopTime(
      place: StopPlace.fromJson(json['place'] as Map<String, dynamic>),
      mode: json['mode'] as String,
      realTime: json['realTime'] as bool,
      headsign: json['headsign'] as String,
      tripTo: json['tripTo'] != null
          ? StopPlace.fromJson(json['tripTo'] as Map<String, dynamic>)
          : null,
      agencyId: json['agencyId'] as String,
      agencyName: json['agencyName'] as String,
      agencyUrl: json['agencyUrl'] as String?,
      routeColor: json['routeColor'] as String?,
      routeTextColor: json['routeTextColor'] as String?,
      tripId: json['tripId'] as String,
      routeType: json['routeType'] as int,
      routeShortName: json['routeShortName'] as String,
      routeLongName: json['routeLongName'] as String,
      displayName: json['displayName'] as String,
      cancelled: json['cancelled'] as bool,
      tripCancelled: json['tripCancelled'] as bool,
    );
  }
}

class StopPlace {
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
  final String? vertexType;
  final String? pickupType;
  final String? dropoffType;
  final bool? cancelled;

  const StopPlace({
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
    this.vertexType,
    this.pickupType,
    this.dropoffType,
    this.cancelled,
  });

  factory StopPlace.fromJson(Map<String, dynamic> json) {
    return StopPlace(
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
      vertexType: json['vertexType'] as String?,
      pickupType: json['pickupType'] as String?,
      dropoffType: json['dropoffType'] as String?,
      cancelled: json['cancelled'] as bool?,
    );
  }
}
