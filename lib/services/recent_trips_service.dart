import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trip_history_item.dart';

class RecentTripsService {
  static const _kRecentTripsKey = 'recent_trips';
  static const int _maxRecentTrips = 5;

  /// Save a trip to history
  /// Deduplicates based on from/to coordinates and keeps only the most recent 5
  static Future<void> saveTrip(TripHistoryItem trip) async {
    final prefs = await SharedPreferences.getInstance();
    final trips = await getRecentTrips();

    // Remove any existing trip with the same route (deduplicate)
    trips.removeWhere((t) => t.dedupeKey == trip.dedupeKey);

    // Add new trip at the beginning
    trips.insert(0, trip);

    // Keep only the most recent trips
    final trimmed = trips.take(_maxRecentTrips).toList();

    // Serialize and save
    final jsonList = trimmed.map((t) => t.toJson()).toList();
    final encoded = jsonEncode(jsonList);
    await prefs.setString(_kRecentTripsKey, encoded);
  }

  /// Get recent trips, ordered from most recent to oldest
  static Future<List<TripHistoryItem>> getRecentTrips() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = prefs.getString(_kRecentTripsKey);
      if (encoded == null || encoded.isEmpty) return [];

      final decoded = jsonDecode(encoded);
      if (decoded is! List) return [];

      final trips = <TripHistoryItem>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        try {
          trips.add(TripHistoryItem.fromJson(item));
        } catch (_) {
          // Skip invalid entries
          continue;
        }
      }

      return trips;
    } catch (_) {
      return [];
    }
  }

  /// Clear all recent trips
  static Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kRecentTripsKey);
  }
}
