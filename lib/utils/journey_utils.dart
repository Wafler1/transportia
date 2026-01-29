import '../models/itinerary.dart';
import '../models/journey_stop.dart';

List<JourneyStop> buildJourneyStops(Leg leg) {
  final stops = <JourneyStop>[];

  stops.add(
    JourneyStop(
      name: leg.fromName,
      lat: leg.fromLat,
      lon: leg.fromLon,
      arrival: null,
      departure: leg.startTime,
      scheduledArrival: null,
      scheduledDeparture: leg.scheduledStartTime,
      track: leg.fromTrack,
      scheduledTrack: leg.fromScheduledTrack,
      cancelled: leg.cancelled,
      alerts: const [],
    ),
  );

  for (final stop in leg.intermediateStops) {
    stops.add(
      JourneyStop(
        name: stop.name,
        lat: stop.lat,
        lon: stop.lon,
        arrival: stop.arrival,
        departure: stop.departure,
        scheduledArrival: stop.scheduledArrival,
        scheduledDeparture: stop.scheduledDeparture,
        track: stop.track,
        scheduledTrack: stop.scheduledTrack,
        cancelled: stop.cancelled,
        alerts: stop.alerts,
      ),
    );
  }

  stops.add(
    JourneyStop(
      name: leg.toName,
      lat: leg.toLat,
      lon: leg.toLon,
      arrival: leg.endTime,
      departure: null,
      scheduledArrival: leg.scheduledEndTime,
      scheduledDeparture: null,
      track: leg.toTrack,
      scheduledTrack: leg.toScheduledTrack,
      cancelled: leg.cancelled,
      alerts: const [],
    ),
  );

  return stops;
}
