import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _accentColorKey = 'accent_color';
  static const String _mapStyleKey = 'map_style';

  // Default values
  static const Color defaultAccentColor = Color.fromARGB(255, 0, 113, 133);
  static const String defaultMapStyle = 'default';

  // Map style URLs
  static const Map<String, String> mapStyleUrls = {
    'default': 'https://tiles.openfreemap.org/styles/liberty',
    'light': 'assets/styles/light.json',
    'dark': 'assets/styles/dark.json',
  };

  Color _accentColor = defaultAccentColor;
  String _mapStyle = defaultMapStyle;
  bool _isInitialized = false;

  Color get accentColor => _accentColor;
  String get mapStyle => _mapStyle;
  String get mapStyleUrl => mapStyleUrls[_mapStyle] ?? mapStyleUrls[defaultMapStyle]!;
  bool get isInitialized => _isInitialized;

  ThemeProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    // Load accent color
    final colorValue = prefs.getInt(_accentColorKey);
    if (colorValue != null) {
      _accentColor = Color(colorValue);
    }

    // Load map style
    _mapStyle = prefs.getString(_mapStyleKey) ?? defaultMapStyle;

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> setAccentColor(Color color) async {
    if (_accentColor == color) return;

    _accentColor = color;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_accentColorKey, color.toARGB32());
  }

  Future<void> resetAccentColor() async {
    if (_accentColor == defaultAccentColor) return;

    _accentColor = defaultAccentColor;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accentColorKey);
  }

  Future<void> setMapStyle(String style) async {
    if (_mapStyle == style) return;
    if (!mapStyleUrls.containsKey(style)) return;

    _mapStyle = style;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_mapStyleKey, style);
  }
}
