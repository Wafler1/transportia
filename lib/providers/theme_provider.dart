import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/prefs_keys.dart';

enum AppThemeMode { light, dark, system }

class ThemeProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const String _accentColorKey = PrefsKeys.accentColor;
  static const String _mapStyleKey = PrefsKeys.mapStyle;
  static const String _appThemeKey = PrefsKeys.appTheme;

  // Default values
  static const Color defaultAccentColor = Color.fromARGB(255, 0, 113, 133);
  static const String defaultMapStyle = 'default';
  static const AppThemeMode defaultAppThemeMode = AppThemeMode.light;

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color darkBackground = Color(0xFF161616);
  static const Color lightText = Color(0xFF000000);
  static const Color darkText = Color(0xFFFFFFFF);

  static ThemeProvider? _instance;

  // TODO: Host remotely
  // Map styles
  static const Map<String, String> mapStyleUrls = {
    'default': 'assets/styles/default.json',
    'light': 'assets/styles/light.json',
    'dark': 'assets/styles/dark.json',
  };

  Color _accentColor = defaultAccentColor;
  String _mapStyle = defaultMapStyle;
  AppThemeMode _appThemeMode = defaultAppThemeMode;
  bool _isInitialized = false;

  static ThemeProvider? get instance => _instance;

  Color get accentColor => _accentColor;
  String get mapStyle => _mapStyle;
  String get mapStyleUrl =>
      mapStyleUrls[_mapStyle] ?? mapStyleUrls[defaultMapStyle]!;
  AppThemeMode get appThemeMode => _appThemeMode;
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

    // Load accent color
    final colorValue = await prefs.getInt(_accentColorKey);
    if (colorValue != null) {
      _accentColor = Color(colorValue);
    }

    // Load map style
    _mapStyle = await prefs.getString(_mapStyleKey) ?? defaultMapStyle;

    final savedTheme = await prefs.getString(_appThemeKey);
    if (savedTheme != null) {
      _appThemeMode = AppThemeMode.values.firstWhere(
        (mode) => mode.name == savedTheme,
        orElse: () => defaultAppThemeMode,
      );
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
