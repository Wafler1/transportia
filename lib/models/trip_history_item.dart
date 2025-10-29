import '../services/transitous_geocode_service.dart';

class TripHistoryItem {
  TripHistoryItem({
    required this.fromName,
    required this.fromLat,
    required this.fromLon,
    required this.toName,
    required this.toLat,
    required this.toLon,
    required this.timestamp,
  });

  final String fromName;
  final double fromLat;
  final double fromLon;
  final String toName;
  final double toLat;
  final double toLon;
  final DateTime timestamp;

  factory TripHistoryItem.fromSelections({
    required TransitousLocationSuggestion? from,
    required TransitousLocationSuggestion to,
    required double? userLat,
    required double? userLon,
  }) {
    String fromName;
    double fromLat;
    double fromLon;

    if (from != null) {
      fromName = from.name;
      fromLat = from.lat;
      fromLon = from.lon;
    } else if (userLat != null && userLon != null) {
      fromName = 'My Location';
      fromLat = userLat;
      fromLon = userLon;
    } else {
      throw ArgumentError('Either from selection or user location must be provided');
    }

    return TripHistoryItem(
      fromName: fromName,
      fromLat: fromLat,
      fromLon: fromLon,
      toName: to.name,
      toLat: to.lat,
      toLon: to.lon,
      timestamp: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'fromName': fromName,
        'fromLat': fromLat,
        'fromLon': fromLon,
        'toName': toName,
        'toLat': toLat,
        'toLon': toLon,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory TripHistoryItem.fromJson(Map<String, dynamic> json) {
    return TripHistoryItem(
      fromName: json['fromName'] as String,
      fromLat: (json['fromLat'] as num).toDouble(),
      fromLon: (json['fromLon'] as num).toDouble(),
      toName: json['toName'] as String,
      toLat: (json['toLat'] as num).toDouble(),
      toLon: (json['toLon'] as num).toDouble(),
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
    );
  }

  // Create a unique key for deduplication
  String get dedupeKey =>
      '${fromLat.toStringAsFixed(3)},${fromLon.toStringAsFixed(3)}->${toLat.toStringAsFixed(3)},${toLon.toStringAsFixed(3)}';
}
