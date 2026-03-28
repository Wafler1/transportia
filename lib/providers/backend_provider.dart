import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/prefs_keys.dart';

class BackendProvider extends ChangeNotifier {
  static const String defaultHost = 'api.transitous.org';
  static const String _defaultGeocode = 'v1';
  static const String _defaultMapStops = 'v1';

  static const List<String> endpointKeys = [
    'plan',
    'trip',
    'stoptimes',
    'mapTrips',
    'mapStops',
    'geocode',
  ];

  static BackendProvider? _instance;
  static BackendProvider? get instance => _instance;

  String _host = defaultHost;
  String? _apiVersionOverride;
  final Map<String, String> _endpointVersions = {};

  String get host => _host;
  bool get isCustomHost => _host != defaultHost;

  String get apiVersion =>
      _apiVersionOverride ?? _computeDefaultApiVersion(_host);
  bool get isCustomApiVersion => _apiVersionOverride != null;

  String get planVersion => _endpointVersions['plan'] ?? apiVersion;
  String get tripVersion => _endpointVersions['trip'] ?? apiVersion;
  String get stopTimesVersion => _endpointVersions['stoptimes'] ?? apiVersion;
  String get mapTripsVersion => _endpointVersions['mapTrips'] ?? apiVersion;

  String get mapStopsVersion =>
      _endpointVersions['mapStops'] ?? _defaultMapStops;

  String get geocodeVersion => _endpointVersions['geocode'] ?? _defaultGeocode;

  bool get hasEndpointOverrides => _endpointVersions.isNotEmpty;
  bool isEndpointOverridden(String key) => _endpointVersions.containsKey(key);
  String? endpointVersionOverride(String key) => _endpointVersions[key];

  static String _computeDefaultApiVersion(String host) =>
      host.contains('transitous') ? 'v5' : 'v1';

  static String _endpointPrefKey(String key) =>
      'transitous_api_version_endpoint_$key';

  BackendProvider() {
    _instance = this;
    _load();
  }

  Future<void> _load() async {
    final prefs = SharedPreferencesAsync();
    final savedHost = await prefs.getString(PrefsKeys.transitousHost);
    final savedVersion = await prefs.getString(PrefsKeys.transitousApiVersion);
    if (savedHost != null && savedHost.isNotEmpty) _host = savedHost;
    if (savedVersion != null && savedVersion.isNotEmpty) {
      _apiVersionOverride = savedVersion;
    }
    for (final key in endpointKeys) {
      final v = await prefs.getString(_endpointPrefKey(key));
      if (v != null && v.isNotEmpty) _endpointVersions[key] = v;
    }
    notifyListeners();
  }

  Future<void> setHost(String host) async {
    final trimmed = host.trim();
    final effective = trimmed.isEmpty ? defaultHost : trimmed;
    if (effective == _host) return;
    _host = effective;
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    if (_host == defaultHost) {
      await prefs.remove(PrefsKeys.transitousHost);
    } else {
      await prefs.setString(PrefsKeys.transitousHost, _host);
    }
  }

  Future<void> resetHost() => setHost(defaultHost);

  Future<void> setApiVersion(String version) async {
    final trimmed = version.trim();
    final computedDefault = _computeDefaultApiVersion(_host);
    final effective = trimmed.isEmpty || trimmed == computedDefault
        ? null
        : trimmed;
    if (effective == _apiVersionOverride) return;
    _apiVersionOverride = effective;
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    if (_apiVersionOverride == null) {
      await prefs.remove(PrefsKeys.transitousApiVersion);
    } else {
      await prefs.setString(
        PrefsKeys.transitousApiVersion,
        _apiVersionOverride!,
      );
    }
  }

  Future<void> resetApiVersion() => setApiVersion('');

  Future<void> setEndpointVersion(String key, String version) async {
    final trimmed = version.trim();
    if (trimmed.isEmpty) return resetEndpointVersion(key);
    if (_endpointVersions[key] == trimmed) return;
    _endpointVersions[key] = trimmed;
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    await prefs.setString(_endpointPrefKey(key), trimmed);
  }

  Future<void> resetEndpointVersion(String key) async {
    if (!_endpointVersions.containsKey(key)) return;
    _endpointVersions.remove(key);
    notifyListeners();
    final prefs = SharedPreferencesAsync();
    await prefs.remove(_endpointPrefKey(key));
  }

  @override
  void dispose() {
    if (_instance == this) _instance = null;
    super.dispose();
  }
}
