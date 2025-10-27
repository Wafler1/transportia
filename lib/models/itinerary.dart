class Itinerary {
  final int duration;
  final DateTime startTime;
  final DateTime endTime;
  final int transfers;
  final List<Leg> legs;
  final bool isDirect;

  Itinerary({
    required this.duration,
    required this.startTime,
    required this.endTime,
    required this.transfers,
    required this.legs,
    this.isDirect = false,
  });

  factory Itinerary.fromJson(Map<String, dynamic> json, {bool isDirect = false}) {
    return Itinerary(
      duration: json['duration'],
      startTime: DateTime.parse(json['startTime']), 
      endTime: DateTime.parse(json['endTime']), 
      transfers: json['transfers'] ?? 0,
      legs: (json['legs'] as List).map((leg) => Leg.fromJson(leg)).toList(),
      isDirect: isDirect,
    );
  }
}

class Leg {
  final String mode;
  final String fromName;
  final String toName;
  final DateTime startTime;
  final DateTime endTime;
  final int duration;
  final String? routeShortName;
  final String? routeLongName;
  final String? headsign;

  Leg({
    required this.mode,
    required this.fromName,
    required this.toName,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.routeShortName,
    this.routeLongName,
    this.headsign,
  });

  factory Leg.fromJson(Map<String, dynamic> json) {
    return Leg(
      mode: json['mode'],
      fromName: json['from']['name'],
      toName: json['to']['name'],
      startTime: DateTime.parse(json['startTime']), 
      endTime: DateTime.parse(json['endTime']), 
      duration: json['duration'],
      routeShortName: json['routeShortName'],
      routeLongName: json['routeLongName'],
      headsign: json['headsign'],
    );
  }
}
