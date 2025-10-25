import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Transparent status + nav bars over the map
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const MapApp());
}

class MapApp extends StatelessWidget {
  const MapApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MapLibre 3D Demo',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF4F8DF7),
        scaffoldBackgroundColor: const Color(0xFF0b0f14),
      ),
      home: const MapScreen(),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // OpenFreeMap hosted style (plug & play)
  static const _styleUrl = "https://tiles.openfreemap.org/styles/liberty";
  static const double _min3DZoom = 16.0;

  // Initial camera (Prague)
  static const CameraPosition _initCam = CameraPosition(
    target: LatLng(50.087, 14.420),
    zoom: 13.0,
    tilt: 0.0,
    bearing: 0.0,
  );

  MaplibreMapController? _controller;
  bool _hasLocationPermission = false;

  // Start camera (overrides Prague if last known location is available)
  CameraPosition _startCam = _initCam;

  // Live camera tracking
  CameraPosition _lastCam = _initCam;

  StreamSubscription<Position>? _posSub;
  LatLng? _lastUserLatLng;
  bool _is3DMode = false;
  bool _didAutoCenter = false; // ensure we auto-center only once per session

  // Trace and coordinate tap features removed

  @override
  void initState() {
    super.initState();
    _ensureLocationReady();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _ensureLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    // Do not show any custom dialogs here; just proceed.

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    if (!mounted) return;
    setState(() {
      _hasLocationPermission = granted;
    });

    if (granted) {
      // Preload last location from our storage first; fallback to device's last-known
      unawaited(_applyPersistedLastLocation());
      unawaited(_applyLastKnownAsStartCamera());
      if (serviceEnabled) _startPositionStream();
    } else {
      await _posSub?.cancel();
      _posSub = null;
      _lastUserLatLng = null;
    }
  }

  static const _kLastLatKey = 'last_gps_lat';
  static const _kLastLngKey = 'last_gps_lng';

  Future<void> _applyPersistedLastLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lat = prefs.getDouble(_kLastLatKey);
      final lng = prefs.getDouble(_kLastLngKey);
      if (lat == null || lng == null) return;
      final cam = CameraPosition(
        target: LatLng(lat, lng),
        zoom: _initCam.zoom,
        tilt: 0.0,
        bearing: 0.0,
      );
      if (!mounted) return;
      setState(() {
        _startCam = cam;
      });
      if (_controller != null && !_didAutoCenter) {
        _lastCam = _startCam;
        await _controller!.moveCamera(
          CameraUpdate.newCameraPosition(_startCam),
        );
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _applyLastKnownAsStartCamera() async {
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        final cam = CameraPosition(
          target: LatLng(last.latitude, last.longitude),
          zoom: _initCam.zoom,
          tilt: 0.0,
          bearing: 0.0,
        );
        if (!mounted) return;
        setState(() {
          _startCam = cam;
        });
        // If map is already created, jump to this start camera
        if (_controller != null && !_didAutoCenter) {
          _lastCam = _startCam;
          await _controller!.moveCamera(
            CameraUpdate.newCameraPosition(_startCam),
          );
        }
      }
    } catch (_) {
      // Ignore errors; keep Prague as fallback
    }
  }

  void _startPositionStream() {
    _posSub?.cancel();
    _posSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((p) {
      final firstFix = _lastUserLatLng == null;
      _lastUserLatLng = LatLng(p.latitude, p.longitude);
      // Persist last known for next app launch
      unawaited(_saveLastLocation(_lastUserLatLng!));
      if (firstFix && !_didAutoCenter) {
        // Auto-center exactly once when we acquire first GPS fix
        _didAutoCenter = true;
        unawaited(_centerOnUser2D());
      }
    }, onError: (e) {
      // swallow permission/other errors
    });
  }

  Future<void> _saveLastLocation(LatLng pos) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kLastLatKey, pos.latitude);
      await prefs.setDouble(_kLastLngKey, pos.longitude);
    } catch (_) {
      // ignore
    }
  }

  // Removed custom dialogs; app remains usable without location services.

  Future<bool> _ensurePermissionOnDemand() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    setState(() {
      _hasLocationPermission = granted;
    });
    if (granted && _posSub == null) _startPositionStream();
    return granted;
  }

  Future<void> _onMapCreated(MaplibreMapController controller) async {
    _controller = controller;
    // If we have a better start camera (last known), move there immediately
    if (_startCam.target != _initCam.target && !_didAutoCenter) {
      _lastCam = _startCam;
      await _controller?.moveCamera(CameraUpdate.newCameraPosition(_startCam));
      if (mounted) setState(() {});
    }
  }

  Future<void> _centerOnUser2D() async {
    // If user triggers this manually, also prevent future auto-pan
    _didAutoCenter = true;
    final ok = await _ensurePermissionOnDemand();
    if (!ok) return;

    LatLng target = _lastUserLatLng ?? _startCam.target;
    if (_lastUserLatLng == null) {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      target = LatLng(pos.latitude, pos.longitude);
      unawaited(_saveLastLocation(target));
    }

    _is3DMode = false;
    _lastCam = CameraPosition(target: target, zoom: 16.0, tilt: 0.0, bearing: 0.0);
    await _controller?.animateCamera(CameraUpdate.newCameraPosition(_lastCam));
    if (mounted) setState(() {});
  }

  /// Toggle 2D <-> 3D using the *current* camera center (tracked in _lastCam).
  Future<void> _toggle3D() async {
    final cam = _lastCam; // always up-to-date thanks to onCameraMove/Idle
    final LatLng target = cam.target;

    if (!_is3DMode) {
      // Enter 3D at current center
      final double targetZoom = cam.zoom < _min3DZoom ? _min3DZoom : cam.zoom;
      _lastCam = CameraPosition(
        target: target,
        zoom: targetZoom + 0.2,
        bearing: cam.bearing, // keep current bearing
        tilt: 60.0,
      );
      await _controller?.animateCamera(CameraUpdate.newCameraPosition(_lastCam));
      _is3DMode = true;
    } else {
      // Back to 2D at the same center
      final double outZoom = cam.zoom > 14.0 ? 14.0 : cam.zoom;
      _lastCam = CameraPosition(
        target: target,
        zoom: outZoom,
        bearing: 0.0,
        tilt: 0.0,
      );
      await _controller?.animateCamera(CameraUpdate.newCameraPosition(_lastCam));
      _is3DMode = false;
    }

    if (mounted) setState(() {});
  }

  void _onCameraMove(CameraPosition pos) {
    _lastCam = pos;
  }

  void _onCameraIdle() {
    // If needed, you can react here; we just ensure _lastCam stays fresh.
  }

  // Removed coordinate bottom sheet and tap handlers

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          MapLibreMap(
            onMapCreated: _onMapCreated,
            styleString: _styleUrl,

            // Show user dot if permitted; we control camera manually
            myLocationEnabled: _hasLocationPermission,
            myLocationRenderMode: _hasLocationPermission
                ? MyLocationRenderMode.compass
                : MyLocationRenderMode.normal,
            myLocationTrackingMode: MyLocationTrackingMode.none,

            // Button-only perspective (avoid gesture confusion):
            rotateGesturesEnabled: false,
            tiltGesturesEnabled: false,

            initialCameraPosition: _startCam,
            compassEnabled: false,

            // Keep _lastCam in sync so toggles use the live center
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,

            // onMapClick/onMapLongClick removed
          ),

          // Floating “glass” controls, top-right
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _GlassIconButton(
                      icon: _is3DMode ? LucideIcons.undoDot : LucideIcons.box,
                      tooltip: _is3DMode ? "Back to 2D" : "3D view",
                      onTap: _toggle3D,
                    ),
                    const SizedBox(height: 10),
                    _GlassIconButton(
                      icon: LucideIcons.locate,
                      tooltip: "My location",
                      onTap: _centerOnUser2D,
                    ),
                  ],
                ),
              ),
            ),
          ),

        ],
      ),
      // No floating action button (trace removed)
    );
  }
}

/// A rounded, semi-transparent icon button that looks good over maps.
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _GlassIconButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final child = IconButton(
      icon: Icon(icon),
      color: Colors.white,
      onPressed: onTap,
      tooltip: tooltip,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: child,
        ),
    );
  }
}

// _GlassPillButton removed (trace feature eliminated)
