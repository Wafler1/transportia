import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritePlace {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final DateTime addedAt;

  const FavoritePlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.addedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lon': lon,
      'addedAt': addedAt.toIso8601String(),
    };
  }

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    return FavoritePlace(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      addedAt: DateTime.parse(json['addedAt'] as String),
    );
  }
}

class FavoritesService {
  static const String _favoritesKey = 'favorite_places';

  static Future<List<FavoritePlace>> getFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonString = prefs.getString(_favoritesKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((item) => FavoritePlace.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveFavorite(FavoritePlace place) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();

      // Check if already exists
      final existingIndex = favorites.indexWhere((f) => f.id == place.id);
      if (existingIndex != -1) {
        return; // Already exists
      }

      favorites.add(place);
      final jsonString = json.encode(favorites.map((f) => f.toJson()).toList());
      await prefs.setString(_favoritesKey, jsonString);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> removeFavorite(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await getFavorites();

      favorites.removeWhere((f) => f.id == id);

      final jsonString = json.encode(favorites.map((f) => f.toJson()).toList());
      await prefs.setString(_favoritesKey, jsonString);
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> isFavorite(String id) async {
    try {
      final favorites = await getFavorites();
      return favorites.any((f) => f.id == id);
    } catch (e) {
      return false;
    }
  }
}
