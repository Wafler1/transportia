enum HomeSection {
  favorites,
  recentTrips,
  departures;

  String get label => switch (this) {
    HomeSection.favorites => 'Favourites',
    HomeSection.recentTrips => 'Recent trips',
    HomeSection.departures => 'Upcoming departures',
  };
}

class HomeSectionConfig {
  const HomeSectionConfig({required this.section, required this.enabled});

  final HomeSection section;
  final bool enabled;

  HomeSectionConfig copyWith({bool? enabled}) {
    return HomeSectionConfig(
      section: section,
      enabled: enabled ?? this.enabled,
    );
  }

  String encode() => '${section.name}:${enabled ? 1 : 0}';

  static HomeSectionConfig? decode(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final section = HomeSection.values.where((s) => s.name == parts[0]);
    if (section.isEmpty) return null;
    return HomeSectionConfig(section: section.first, enabled: parts[1] == '1');
  }

  static const List<HomeSectionConfig> defaults = [
    HomeSectionConfig(section: HomeSection.favorites, enabled: true),
    HomeSectionConfig(section: HomeSection.recentTrips, enabled: true),
    HomeSectionConfig(section: HomeSection.departures, enabled: true),
  ];
}
