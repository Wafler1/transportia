import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/prefs_keys.dart';
import '../models/trip_history_item.dart';

class RecentTripsService {
  static const _kRecentTripsKey = PrefsKeys.recentTrips;
  static const int _maxRecentTrips = 5;

  static Future<void> saveTrip(TripHistoryItem trip) async {
    final prefs = SharedPreferencesAsync();
    final trips = await getRecentTrips();
    trips.removeWhere((t) => t.dedupeKey == trip.dedupeKey);
    trips.insert(0, trip);
    final trimmed = trips.take(_maxRecentTrips).toList();
    final jsonList = trimmed.map((t) => t.toJson()).toList();
    final encoded = jsonEncode(jsonList);
    await prefs.setString(_kRecentTripsKey, encoded);
  }

  static Future<List<TripHistoryItem>> getRecentTrips() async {
    try {
      final prefs = SharedPreferencesAsync();
      final encoded = await prefs.getString(_kRecentTripsKey);
      if (encoded == null || encoded.isEmpty) return [];

      final decoded = jsonDecode(encoded);
      if (decoded is! List) return [];

      final trips = <TripHistoryItem>[];
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        try {
          trips.add(TripHistoryItem.fromJson(item));
        } catch (_) {
          continue;
        }
      }

      return trips;
    } catch (_) {
      return [];
    }
  }

  static Future<void> clearHistory() async {
    final prefs = SharedPreferencesAsync();
    await prefs.remove(_kRecentTripsKey);
  }
}
