class SavedPlace {
  const SavedPlace({
    required this.name,
    required this.type,
    required this.lat,
    required this.lon,
    required this.importance,
    this.city,
    this.countryCode,
  });

  static const int keyPrecision = 5;
  static const int defaultImportance = 15;

  final String name;
  final String type;
  final double lat;
  final double lon;
  final int importance;
  final String? city;
  final String? countryCode;

  String get key => buildKey(type: type, lat: lat, lon: lon);

  SavedPlace copyWith({
    String? name,
    String? type,
    double? lat,
    double? lon,
    int? importance,
    String? city,
    String? countryCode,
  }) {
    return SavedPlace(
      name: name ?? this.name,
      type: type ?? this.type,
      lat: lat ?? this.lat,
      lon: lon ?? this.lon,
      importance: importance ?? this.importance,
      city: city ?? this.city,
      countryCode: countryCode ?? this.countryCode,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type,
      'lat': lat,
      'lon': lon,
      'importance': importance,
      'city': city,
      'countryCode': countryCode,
    };
  }

  static SavedPlace? fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String?;
    final type = json['type'] as String?;
    final lat = (json['lat'] as num?)?.toDouble();
    final lon = (json['lon'] as num?)?.toDouble();
    final importance =
        (json['importance'] as num?)?.toInt() ?? SavedPlace.defaultImportance;
    final city = json['city'] as String?;
    final countryCode =
        (json['countryCode'] as String?) ?? (json['country'] as String?);
    if (name == null || name.trim().isEmpty) return null;
    if (type == null || type.trim().isEmpty) return null;
    if (lat == null || lon == null) return null;
    return SavedPlace(
      name: name,
      type: type,
      lat: lat,
      lon: lon,
      importance: importance,
      city: city,
      countryCode: countryCode,
    );
  }

  static String buildKey({
    required String type,
    required double lat,
    required double lon,
  }) {
    final normalizedType = type.trim().toLowerCase();
    final latKey = lat.toStringAsFixed(keyPrecision);
    final lonKey = lon.toStringAsFixed(keyPrecision);
    return '$normalizedType|$latKey|$lonKey';
  }
}
