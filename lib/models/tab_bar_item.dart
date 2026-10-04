enum TabBarItem {
  departures,
  savedTrips;

  String get label => switch (this) {
    TabBarItem.departures => 'Departures',
    TabBarItem.savedTrips => 'Saved trips',
  };
}

/// Whether [item] shows as a tab in the main bottom bar, or (when false) as
/// a settings entry instead. Main (search) and Settings are always tabs and
/// aren't configurable — this only covers the two optional slots between
/// them.
class TabBarItemConfig {
  const TabBarItemConfig({required this.item, required this.enabledAsTab});

  final TabBarItem item;
  final bool enabledAsTab;

  TabBarItemConfig copyWith({bool? enabledAsTab}) {
    return TabBarItemConfig(
      item: item,
      enabledAsTab: enabledAsTab ?? this.enabledAsTab,
    );
  }

  String encode() => '${item.name}:${enabledAsTab ? 1 : 0}';

  static TabBarItemConfig? decode(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final item = TabBarItem.values.where((i) => i.name == parts[0]);
    if (item.isEmpty) return null;
    return TabBarItemConfig(item: item.first, enabledAsTab: parts[1] == '1');
  }

  // Matches today's fixed layout: Departures is a tab, Saved trips isn't.
  static const List<TabBarItemConfig> defaults = [
    TabBarItemConfig(item: TabBarItem.departures, enabledAsTab: true),
    TabBarItemConfig(item: TabBarItem.savedTrips, enabledAsTab: false),
  ];
}
