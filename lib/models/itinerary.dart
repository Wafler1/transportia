class FareInfo {
  final double amount;
  final String currency;

  FareInfo({
    required this.amount,
    required this.currency,
  });

  factory FareInfo.fromJson(Map<String, dynamic> json) {
    return FareInfo(
      amount: json['amount']?.toDouble() ?? 0.0,
      currency: json['currency'] ?? '',
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

  factory Itinerary.fromJson(Map<String, dynamic> json, {bool isDirect = false}) {
    // Extract fare from fareTransfers if available
    FareInfo? fare;
    if (json['fareTransfers'] != null && (json['fareTransfers'] as List).isNotEmpty) {
      final fareTransfer = (json['fareTransfers'] as List).first;
      if (fareTransfer['transferProducts'] != null &&
          (fareTransfer['transferProducts'] as List).isNotEmpty) {
        fare = FareInfo.fromJson((fareTransfer['transferProducts'] as List).first);
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
  final int duration;
  final double? distance; // Distance in meters
  final String? routeShortName;
  final String? routeLongName;
  final String? headsign;
  // Hex color strings like "#FF0000" for UI styling.
  final String? routeColor;
  final String? routeTextColor;

  Leg({
    required this.mode,
    required this.fromName,
    required this.toName,
    required this.startTime,
    required this.endTime,
    required this.duration,
    this.distance,
    this.routeShortName,
    this.routeLongName,
    this.headsign,
    this.routeColor,
    this.routeTextColor,
  });

  factory Leg.fromJson(Map<String, dynamic> json) {
    return Leg(
      mode: json['mode'],
      fromName: json['from']['name'],
      toName: json['to']['name'],
      startTime: DateTime.parse(json['startTime']),
      endTime: DateTime.parse(json['endTime']),
      duration: json['duration'],
      distance: json['distance']?.toDouble(),
      routeShortName: json['routeShortName'],
      routeLongName: json['routeLongName'],
      headsign: json['headsign'],
      routeColor: json['routeColor'],
      routeTextColor: json['routeTextColor'],
    );
  }
}
