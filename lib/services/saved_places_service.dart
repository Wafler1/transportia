import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/prefs_keys.dart';
import '../models/saved_place.dart';

enum SavedPlacesBucket { search, timetable }

class SavedPlacesService {
  static const String _searchKey = PrefsKeys.savedPlacesSearch;
  static const String _timetableKey = PrefsKeys.savedPlacesTimetable;
  static const int maxPlaces = 50;
  static const int importanceStep = 3;
  static const int initialImportance = 15;

  static Future<List<SavedPlace>> loadPlaces({
    required SavedPlacesBucket bucket,
  }) async {
    final prefs = SharedPreferencesAsync();
    final raw = await prefs.getString(_keyFor(bucket));
    if (raw == null || raw.isEmpty) {
      return <SavedPlace>[];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return <SavedPlace>[];
    }
    final places = <SavedPlace>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      final place = SavedPlace.fromJson(entry);
      if (place != null) {
        places.add(place);
      }
    }
    return _normalize(places);
  }

  static Future<void> savePlaces({
    required SavedPlacesBucket bucket,
    required List<SavedPlace> places,
  }) async {
    final prefs = SharedPreferencesAsync();
    final normalized = _normalize(places);
    final encoded = jsonEncode(
      normalized.map((place) => place.toJson()).toList(growable: false),
    );
    await prefs.setString(_keyFor(bucket), encoded);
  }

  static List<SavedPlace> applySelection(
    List<SavedPlace> places,
    SavedPlace selected,
  ) {
    final normalizedKey = selected.key;
    final updated = <SavedPlace>[];
    bool matched = false;

    for (final place in places) {
      if (place.key == normalizedKey) {
        matched = true;
        updated.add(
          place.copyWith(
            name: selected.name,
            type: selected.type,
            lat: selected.lat,
            lon: selected.lon,
            importance: place.importance + importanceStep,
            city: selected.city ?? place.city,
            countryCode: selected.countryCode ?? place.countryCode,
          ),
        );
      } else {
        final nextImportance = place.importance - 1;
        if (nextImportance > 0) {
          updated.add(place.copyWith(importance: nextImportance));
        }
      }
    }

    if (!matched) {
      updated.add(selected.copyWith(importance: initialImportance));
    }

    return _normalize(updated);
  }

  static List<SavedPlace> _normalize(List<SavedPlace> places) {
    final filtered = [
      for (final place in places)
        if (place.importance > 0 && place.name.trim().isNotEmpty) place,
    ];
    filtered.sort((a, b) {
      final diff = b.importance.compareTo(a.importance);
      if (diff != 0) return diff;
      return a.name.compareTo(b.name);
    });
    if (filtered.length > maxPlaces) {
      filtered.removeRange(maxPlaces, filtered.length);
    }
    return filtered;
  }

  static String _keyFor(SavedPlacesBucket bucket) {
    return switch (bucket) {
      SavedPlacesBucket.search => _searchKey,
      SavedPlacesBucket.timetable => _timetableKey,
    };
  }
}
