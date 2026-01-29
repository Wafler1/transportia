import 'itinerary.dart';

class JourneyStop {
  const JourneyStop({
    required this.name,
    required this.lat,
    required this.lon,
    required this.arrival,
    required this.departure,
    required this.scheduledArrival,
    required this.scheduledDeparture,
    required this.track,
    required this.scheduledTrack,
    required this.cancelled,
    required this.alerts,
  });

  final String name;
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
}
