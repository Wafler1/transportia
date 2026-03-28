import 'itinerary.dart';

class ItineraryResponse {
  final List<Itinerary> itineraries;
  final String? nextPageCursor;
  final String? previousPageCursor;

  const ItineraryResponse({
    required this.itineraries,
    this.nextPageCursor,
    this.previousPageCursor,
  });

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
      previousPageCursor: json['previousPageCursor'] as String?,
    );
  }
}
