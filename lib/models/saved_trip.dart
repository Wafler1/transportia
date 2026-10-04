import 'itinerary.dart';

/// A full itinerary the user chose to keep for later, offline viewing —
/// distinct from a recent *search* (`TripHistoryItem`), which only
/// remembers the query, not the result.
class SavedTrip {
  const SavedTrip({
    required this.id,
    required this.itinerary,
    required this.fromName,
    required this.fromLat,
    required this.fromLon,
    required this.toName,
    required this.toLat,
    required this.toLon,
    required this.savedAt,
  });

  final String id;
  final Itinerary itinerary;
  final String fromName;
  final double fromLat;
  final double fromLon;
  final String toName;
  final double toLat;
  final double toLon;
  final DateTime savedAt;

  bool get isPast => itinerary.endTime.isBefore(DateTime.now());

  /// Identifies "the same trip" regardless of when it was saved, so saving
  /// twice doesn't create duplicates.
  String get dedupeKey =>
      '${fromLat.toStringAsFixed(4)},${fromLon.toStringAsFixed(4)}'
      '->${toLat.toStringAsFixed(4)},${toLon.toStringAsFixed(4)}'
      '@${itinerary.startTime.toIso8601String()}';

  /// Derives the saved from/to points from the itinerary's own endpoints
  /// (first leg's origin, last leg's destination) rather than requiring the
  /// original search suggestion to be threaded through every screen that
  /// can save a trip.
  factory SavedTrip.fromItinerary(Itinerary itinerary) {
    final legs = itinerary.legs;
    final firstLeg = legs.first;
    final lastLeg = legs.last;

    // Walking legs' own from/to names are often generic placeholders (e.g.
    // "START"/"END") rather than real places — prefer the name of the stop
    // the walk actually leads to/from. Coordinates stay the true physical
    // endpoints regardless; only the displayed name changes.
    final fromName = firstLeg.mode == 'WALK'
        ? legs.firstWhere((l) => l.mode != 'WALK', orElse: () => firstLeg).fromName
        : firstLeg.fromName;
    final toName = lastLeg.mode == 'WALK'
        ? legs.lastWhere((l) => l.mode != 'WALK', orElse: () => lastLeg).toName
        : lastLeg.toName;

    return SavedTrip(
      id: 'saved_${DateTime.now().millisecondsSinceEpoch}',
      itinerary: itinerary,
      fromName: fromName,
      fromLat: firstLeg.fromLat,
      fromLon: firstLeg.fromLon,
      toName: toName,
      toLat: lastLeg.toLat,
      toLon: lastLeg.toLon,
      savedAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itinerary': itinerary.toJson(),
      'fromName': fromName,
      'fromLat': fromLat,
      'fromLon': fromLon,
      'toName': toName,
      'toLat': toLat,
      'toLon': toLon,
      'savedAt': savedAt.toIso8601String(),
    };
  }

  factory SavedTrip.fromJson(Map<String, dynamic> json) {
    final itineraryJson = (json['itinerary'] as Map).cast<String, dynamic>();
    return SavedTrip(
      id: json['id'] as String,
      itinerary: Itinerary.fromJson(
        itineraryJson,
        isDirect: itineraryJson['isDirect'] as bool? ?? false,
      ),
      fromName: json['fromName'] as String,
      fromLat: (json['fromLat'] as num).toDouble(),
      fromLon: (json['fromLon'] as num).toDouble(),
      toName: json['toName'] as String,
      toLat: (json['toLat'] as num).toDouble(),
      toLon: (json['toLon'] as num).toDouble(),
      savedAt: DateTime.parse(json['savedAt'] as String),
    );
  }

  SavedTrip withItinerary(Itinerary updated) {
    return SavedTrip(
      id: id,
      itinerary: updated,
      fromName: fromName,
      fromLat: fromLat,
      fromLon: fromLon,
      toName: toName,
      toLat: toLat,
      toLon: toLon,
      savedAt: savedAt,
    );
  }
}
