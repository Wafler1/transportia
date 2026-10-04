import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/prefs_keys.dart';
import '../models/home_section.dart';
import '../models/tab_bar_item.dart';

enum AppThemeMode { light, dark, system }

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const String _accentColorKey = PrefsKeys.accentColor;
  static const String _mapStyleKey = PrefsKeys.mapStyle;
  static const String _appThemeKey = PrefsKeys.appTheme;
  static const String _vibrationsEnabledKey = PrefsKeys.vibrationsEnabled;
  static const String _geocodeLocationBiasEnabledKey =
      PrefsKeys.geocodeLocationBiasEnabled;
  static const String _homeSectionsKey = PrefsKeys.homeSections;
  static const String _backgroundTrackingEnabledKey =
      PrefsKeys.backgroundTrackingEnabled;
  static const String _showGtfsFieldsKey = PrefsKeys.showGtfsFields;
  static const String _tabBarItemsKey = PrefsKeys.tabBarItems;

  static const Color defaultAccentColor = Color.fromARGB(255, 0, 113, 133);
  static const String defaultMapStyle = 'default';
  static const AppThemeMode defaultAppThemeMode = AppThemeMode.light;
  static const bool defaultVibrationsEnabled = true;
  static const bool defaultGeocodeLocationBiasEnabled = true;
  static const bool defaultBackgroundTrackingEnabled = true;
  static const bool defaultShowGtfsFields = false;

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF161616);
  static const Color lightText = Color(0xFF000000);
  static const Color darkText = Color(0xFFFFFFFF);

  static ThemeProvider? _instance;

  // TODO: Host remotely
  static const Map<String, String> mapStyleUrls = {
    'default': 'assets/styles/default.json',
    'light': 'assets/styles/light.json',
    'dark': 'assets/styles/dark.json',
  };

  Color _accentColor = defaultAccentColor;
  String _mapStyle = defaultMapStyle;
  AppThemeMode _appThemeMode = defaultAppThemeMode;
  bool _vibrationsEnabled = defaultVibrationsEnabled;
  bool _geocodeLocationBiasEnabled = defaultGeocodeLocationBiasEnabled;
  bool _backgroundTrackingEnabled = defaultBackgroundTrackingEnabled;
  bool _showGtfsFields = defaultShowGtfsFields;
  List<HomeSectionConfig> _homeSections = HomeSectionConfig.defaults;
  List<TabBarItemConfig> _tabBarItems = TabBarItemConfig.defaults;
  bool _isInitialized = false;

  static ThemeProvider? get instance => _instance;

  Color get accentColor => _accentColor;
  String get mapStyle => _mapStyle;
  String get mapStyleUrl =>
      mapStyleUrls[_mapStyle] ?? mapStyleUrls[defaultMapStyle]!;
  AppThemeMode get appThemeMode => _appThemeMode;
  bool get vibrationsEnabled => _vibrationsEnabled;
  bool get geocodeLocationBiasEnabled => _geocodeLocationBiasEnabled;
  bool get backgroundTrackingEnabled => _backgroundTrackingEnabled;
  bool get showGtfsFields => _showGtfsFields;
  List<HomeSectionConfig> get homeSections =>
      List.unmodifiable(_homeSections);
  List<TabBarItemConfig> get tabBarItems => List.unmodifiable(_tabBarItems);
  bool get isInitialized => _isInitialized;

  AppThemeMode get _effectiveAppThemeMode {
    if (_appThemeMode == AppThemeMode.system) {
      final brightness =
          WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark
          ? AppThemeMode.dark
          : AppThemeMode.light;
    }
    return _appThemeMode;
  }

  bool get isDark => _effectiveAppThemeMode == AppThemeMode.dark;

  Color get backgroundColor => isDark ? darkBackground : lightBackground;

  Color get textColor => isDark ? darkText : lightText;

  ThemeProvider() {
    _instance = this;
    WidgetsBinding.instance.addObserver(this);
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = SharedPreferencesAsync();

    final colorValue = await prefs.getInt(_accentColorKey);
    if (colorValue != null) {
      _accentColor = Color(colorValue);
    }

    _mapStyle = await prefs.getString(_mapStyleKey) ?? defaultMapStyle;

    final savedTheme = await prefs.getString(_appThemeKey);
    if (savedTheme != null) {
      _appThemeMode = AppThemeMode.values.firstWhere(
        (mode) => mode.name == savedTheme,
        orElse: () => defaultAppThemeMode,
      );
    }

    _vibrationsEnabled =
        await prefs.getBool(_vibrationsEnabledKey) ?? defaultVibrationsEnabled;

    _geocodeLocationBiasEnabled =
        await prefs.getBool(_geocodeLocationBiasEnabledKey) ??
        defaultGeocodeLocationBiasEnabled;

    _backgroundTrackingEnabled =
        await prefs.getBool(_backgroundTrackingEnabledKey) ??
        defaultBackgroundTrackingEnabled;

    _showGtfsFields =
        await prefs.getBool(_showGtfsFieldsKey) ?? defaultShowGtfsFields;

    final savedSections = await prefs.getStringList(_homeSectionsKey);
    if (savedSections != null && savedSections.isNotEmpty) {
      final decoded = savedSections
          .map(HomeSectionConfig.decode)
          .whereType<HomeSectionConfig>()
          .toList();
      // Keep any newly added sections that aren't in the saved list yet,
      // appended in their default order and enabled.
      final knownSections = decoded.map((c) => c.section).toSet();
      for (final defaultConfig in HomeSectionConfig.defaults) {
        if (!knownSections.contains(defaultConfig.section)) {
          decoded.add(defaultConfig);
        }
      }
      if (decoded.isNotEmpty) {
        _homeSections = decoded;
      }
    }

    final savedTabBarItems = await prefs.getStringList(_tabBarItemsKey);
    if (savedTabBarItems != null && savedTabBarItems.isNotEmpty) {
      final decoded = savedTabBarItems
          .map(TabBarItemConfig.decode)
          .whereType<TabBarItemConfig>()
          .toList();
      final knownItems = decoded.map((c) => c.item).toSet();
      for (final defaultConfig in TabBarItemConfig.defaults) {
        if (!knownItems.contains(defaultConfig.item)) {
          decoded.add(defaultConfig);
        }
      }
      if (decoded.isNotEmpty) {
        _tabBarItems = decoded;
      }
    }

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    if (_accentColor == color) return;

    _accentColor = color;
    notifyListeners();

    final prefs = SharedPreferencesAsync();
    await prefs.setInt(_accentColorKey, color.toARGB32());
  }

  Future<void> resetAccentColor() async {
    if (_accentColor == defaultAccentColor) return;

    _accentColor = defaultAccentColor;
    notifyListeners();

    final prefs = SharedPreferencesAsync();
    await prefs.remove(_accentColorKey);
  }

  Future<void> setMapStyle(String style) async {
    if (_mapStyle == style) return;
    if (!mapStyleUrls.containsKey(style)) return;

    _mapStyle = style;
    notifyListeners();

    final prefs = SharedPreferencesAsync();
    await prefs.setString(_mapStyleKey, style);
  }

  Future<void> setAppThemeMode(AppThemeMode mode) async {
    if (_appThemeMode == mode) return;

    _appThemeMode = mode;
    notifyListeners();

    final prefs = SharedPreferencesAsync();
    await prefs.setString(_appThemeKey, mode.name);
  }

  Future<void> setVibrationsEnabled(bool enabled) async {
    if (_vibrationsEnabled == enabled) return;

    _vibrationsEnabled = enabled;
    notifyListeners();

    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_vibrationsEnabledKey, enabled);
  }

  Future<void> setGeocodeLocationBiasEnabled(bool enabled) async {
    if (_geocodeLocationBiasEnabled == enabled) return;

    _geocodeLocationBiasEnabled = enabled;
    notifyListeners();

    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_geocodeLocationBiasEnabledKey, enabled);
  }

  Future<void> setBackgroundTrackingEnabled(bool enabled) async {
    if (_backgroundTrackingEnabled == enabled) return;

    _backgroundTrackingEnabled = enabled;
    notifyListeners();

    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_backgroundTrackingEnabledKey, enabled);
  }

  Future<void> setShowGtfsFields(bool enabled) async {
    if (_showGtfsFields == enabled) return;

    _showGtfsFields = enabled;
    notifyListeners();

    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_showGtfsFieldsKey, enabled);
  }

  Future<void> setHomeSections(List<HomeSectionConfig> sections) async {
    _homeSections = List.unmodifiable(sections);
    notifyListeners();

    final prefs = SharedPreferencesAsync();
    await prefs.setStringList(
      _homeSectionsKey,
      sections.map((c) => c.encode()).toList(growable: false),
    );
  }

  Future<void> setTabBarItems(List<TabBarItemConfig> items) async {
    _tabBarItems = List.unmodifiable(items);
    notifyListeners();

    final prefs = SharedPreferencesAsync();
    await prefs.setStringList(
      _tabBarItemsKey,
      items.map((c) => c.encode()).toList(growable: false),
    );
  }

  @override
  void didChangePlatformBrightness() {
    if (_appThemeMode == AppThemeMode.system) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_instance == this) {
      _instance = null;
    }
    super.dispose();
  }
}
