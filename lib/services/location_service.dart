import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocationService {
  static const _kLastLatKey = 'last_gps_lat';
  static const _kLastLngKey = 'last_gps_lng';

  static Future<bool> hasPermission() async {
    final p = await Geolocator.checkPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  static Future<bool> ensurePermission() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied || p == LocationPermission.deniedForever) {
      p = await Geolocator.requestPermission();
    }
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  static Stream<Position> positionStream({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(accuracy: accuracy, distanceFilter: distanceFilter),
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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kLastLatKey, v.latitude);
    await prefs.setDouble(_kLastLngKey, v.longitude);
  }

  static Future<LatLng?> loadLastLatLng() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble(_kLastLatKey);
    final lng = prefs.getDouble(_kLastLngKey);
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }
}

