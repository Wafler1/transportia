import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/prefs_keys.dart';
import '../models/itinerary.dart';
import '../models/saved_trip.dart';

class SavedTripsService {
  static const String _savedTripsKey = PrefsKeys.savedTrips;
  static final ValueNotifier<List<SavedTrip>> savedTripsListenable =
      ValueNotifier<List<SavedTrip>>(<SavedTrip>[]);

  static Future<List<SavedTrip>> getSavedTrips() async {
    final trips = await _readTrips();
    savedTripsListenable.value = List.unmodifiable(trips);
    return trips;
  }

  /// Saves [trip] unless a trip with the same [SavedTrip.dedupeKey] is
  /// already saved. Returns true if it was newly saved.
  static Future<bool> saveTrip(SavedTrip trip) async {
    final prefs = SharedPreferencesAsync();
    final trips = await _readTrips(prefs: prefs);
    if (trips.any((t) => t.dedupeKey == trip.dedupeKey)) return false;

    trips.insert(0, trip);
    await _persistTrips(prefs, trips);
    savedTripsListenable.value = List.unmodifiable(trips);
    return true;
  }

  static Future<void> removeTrip(String id) async {
    final prefs = SharedPreferencesAsync();
    final trips = await _readTrips(prefs: prefs);
    trips.removeWhere((t) => t.id == id);
    await _persistTrips(prefs, trips);
    savedTripsListenable.value = List.unmodifiable(trips);
  }

  /// Substitutes a refreshed [Itinerary] into the saved trip with [id] (e.g.
  /// after a pull-to-refresh re-fetches real-time leg data), keeping its
  /// saved metadata (id, original from/to, savedAt) unchanged.
  static Future<void> replaceTrip(String id, Itinerary updated) async {
    final prefs = SharedPreferencesAsync();
    final trips = await _readTrips(prefs: prefs);
    final index = trips.indexWhere((t) => t.id == id);
    if (index == -1) return;
    trips[index] = trips[index].withItinerary(updated);
    await _persistTrips(prefs, trips);
    savedTripsListenable.value = List.unmodifiable(trips);
  }

  static Future<bool> isSaved(String dedupeKey) async {
    final trips = await _readTrips();
    return trips.any((t) => t.dedupeKey == dedupeKey);
  }

  static Future<List<SavedTrip>> _readTrips({
    SharedPreferencesAsync? prefs,
  }) async {
    try {
      final storage = prefs ?? SharedPreferencesAsync();
      final jsonString = await storage.getString(_savedTripsKey);
      if (jsonString == null || jsonString.isEmpty) return <SavedTrip>[];

      final jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((item) => SavedTrip.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return <SavedTrip>[];
    }
  }

  static Future<void> _persistTrips(
    SharedPreferencesAsync prefs,
    List<SavedTrip> trips,
  ) async {
    final encoded = json.encode(
      trips.map((t) => t.toJson()).toList(growable: false),
    );
    await prefs.setString(_savedTripsKey, encoded);
  }
}
