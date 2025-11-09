import 'itinerary.dart';

/// Response wrapper for the routing API that supports pagination.
///
/// The API returns a list of direct itineraries and regular itineraries.
/// It may also include a `nextPageCursor` field for fetching additional
/// results. This class mirrors the structure used by `StopTimesResponse`.
class ItineraryResponse {
  final List<Itinerary> itineraries;
  final String? nextPageCursor;

  const ItineraryResponse({required this.itineraries, this.nextPageCursor});

  factory ItineraryResponse.fromJson(Map<String, dynamic> json) {
    final direct = json['direct'] as List? ?? [];
    final itineraries = json['itineraries'] as List? ?? [];

    final List<Itinerary> result = [];
    result.addAll(
      direct.map(
        (item) =>
            Itinerary.fromJson(item as Map<String, dynamic>, isDirect: true),
      ),
    );
    result.addAll(
      itineraries.map(
        (item) => Itinerary.fromJson(item as Map<String, dynamic>),
      ),
    );

    return ItineraryResponse(
      itineraries: result,
      nextPageCursor: json['nextPageCursor'] as String?,
    );
  }
}
