import '../models/stop_time.dart';

List<StopTime> deduplicateStopTimes(List<StopTime> stopTimes) {
  final seen = <String>{};
  final deduped = <StopTime>[];
  for (final stopTime in stopTimes) {
    final departure = stopTime.place.departure?.toIso8601String() ?? '';
    final key = '${stopTime.tripId}|$departure|${stopTime.headsign}';
    if (seen.add(key)) {
      deduped.add(stopTime);
    }
  }
  return deduped;
}
