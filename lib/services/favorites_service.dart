import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FavoritePlace {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final DateTime addedAt;
  final String iconName;

  const FavoritePlace({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    required this.addedAt,
    this.iconName = 'mapPin',
  });

  FavoritePlace copyWith({
    String? id,
    String? name,
    double? lat,
    double? lon,
    DateTime? addedAt,
    String? iconName,
  }) {
    return FavoritePlace(
      id: id ?? this.id,
      name: name ?? this.name,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      addedAt: addedAt ?? this.addedAt,
      iconName: iconName ?? this.iconName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'lat': lat,
      'lon': lon,
      'addedAt': addedAt.toIso8601String(),
      'iconName': iconName,
    };
  }

  factory FavoritePlace.fromJson(Map<String, dynamic> json) {
    return FavoritePlace(
      id: json['id'] as String,
      name: json['name'] as String,
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      addedAt: DateTime.parse(json['addedAt'] as String),
      iconName: json['iconName'] as String? ?? 'mapPin',
    );
  }
}

class FavoritesService {
  static const String _favoritesKey = 'favorite_places';
  static final ValueNotifier<List<FavoritePlace>> favoritesListenable =
      ValueNotifier<List<FavoritePlace>>(<FavoritePlace>[]);

  static Future<List<FavoritePlace>> getFavorites() async {
    final favourites = await _readFavorites();
    favoritesListenable.value = List.unmodifiable(favourites);
    return favourites;
  }

  static Future<void> saveFavorite(FavoritePlace place) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await _readFavorites(prefs: prefs);
      final exists = favorites.any((f) => f.id == place.id);
      if (exists) return;

      favorites.insert(0, place);
      await _persistFavorites(prefs, favorites);
      favoritesListenable.value = List.unmodifiable(favorites);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> removeFavorite(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await _readFavorites(prefs: prefs);
      favorites.removeWhere((f) => f.id == id);
      await _persistFavorites(prefs, favorites);
      favoritesListenable.value = List.unmodifiable(favorites);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> updateFavorite(FavoritePlace updatedPlace) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = await _readFavorites(prefs: prefs);
      final index = favorites.indexWhere((f) => f.id == updatedPlace.id);
      if (index != -1) {
        favorites[index] = updatedPlace;
        await _persistFavorites(prefs, favorites);
        favoritesListenable.value = List.unmodifiable(favorites);
      }
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> reorderFavorites(List<FavoritePlace> reordered) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = List<FavoritePlace>.from(reordered);
      await _persistFavorites(prefs, favorites);
      favoritesListenable.value = List.unmodifiable(favorites);
    } catch (e) {
      rethrow;
    }
  }

  static Future<bool> isFavorite(String id) async {
    try {
      final favorites = await _readFavorites();
      return favorites.any((f) => f.id == id);
    } catch (e) {
      return false;
    }
  }

  static Future<List<FavoritePlace>> _readFavorites({
    SharedPreferences? prefs,
  }) async {
    try {
      final storage = prefs ?? await SharedPreferences.getInstance();
      final String? jsonString = storage.getString(_favoritesKey);
      if (jsonString == null || jsonString.isEmpty) {
        return <FavoritePlace>[];
      }

      final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;
      return jsonList
          .map((item) => FavoritePlace.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      return <FavoritePlace>[];
    }
  }

  static Future<void> _persistFavorites(
    SharedPreferences prefs,
    List<FavoritePlace> favorites,
  ) async {
    final encoded = json.encode(
      favorites.map((f) => f.toJson()).toList(growable: false),
    );
    await prefs.setString(_favoritesKey, encoded);
  }
}
