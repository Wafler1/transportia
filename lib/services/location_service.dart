import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import '../constants/prefs_keys.dart';

class LocationService {
  static const _kLastLatKey = PrefsKeys.lastGpsLat;
  static const _kLastLngKey = PrefsKeys.lastGpsLng;
  static Future<bool>? _pendingPermissionRequest;

  static Future<bool> hasPermission() async {
    final status = await Permission.locationWhenInUse.status;
    return status.isGranted;
  }

  static Future<bool> ensurePermission() async {
    final status = await Permission.locationWhenInUse.status;
    if (status.isGranted) return true;
    final pending = _pendingPermissionRequest;
    if (pending != null) return pending;
    final request = Permission.locationWhenInUse
        .request()
        .then((result) => result.isGranted)
        .catchError((_) => false);
    _pendingPermissionRequest = request;
    final granted = await request;
    _pendingPermissionRequest = null;
    return granted;
  }

  /// Read-only status checks (never prompt), used to explain why the
  /// background-tracking setting is unavailable.
  static Future<bool> hasLocationAlwaysPermission() async {
    final status = await Permission.locationAlways.status;
    return status.isGranted;
  }

  static Future<bool> hasNotificationPermission() async {
    final status = await Permission.notification.status;
    return status.isGranted;
  }

  /// Requests "allow all the time" location plus notification permission,
  /// needed to keep itinerary tracking running via a background notification.
  /// Never throws; returns false on denial so callers can silently fall back
  /// to foreground-only tracking.
  static Future<bool> ensureBackgroundPermission() async {
    try {
      if (!await ensurePermission()) return false;
      final backgroundStatus = await Permission.locationAlways.request();
      if (!backgroundStatus.isGranted) return false;
      final notificationStatus = await Permission.notification.request();
      return notificationStatus.isGranted;
    } catch (_) {
      return false;
    }
  }

  static Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    );
  }

  static Future<Position?> lastKnownPosition() {
    return Geolocator.getLastKnownPosition();
  }

  static Future<Position> currentPosition({
    LocationAccuracy accuracy = LocationAccuracy.best,
  }) {
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(accuracy: accuracy),
    );
  }

  static Future<void> saveLastLatLng(LatLng v) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setDouble(_kLastLatKey, v.latitude);
    await prefs.setDouble(_kLastLngKey, v.longitude);
  }

  static Future<LatLng?> loadLastLatLng() async {
    final prefs = SharedPreferencesAsync();
    final lat = await prefs.getDouble(_kLastLatKey);
    final lng = await prefs.getDouble(_kLastLngKey);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }
}
