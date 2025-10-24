import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

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

  // Live camera tracking
  CameraPosition _lastCam = _initCam;

  StreamSubscription<Position>? _posSub;
  LatLng? _lastUserLatLng;
  bool _is3DMode = false;

  final List<Symbol> _symbols = [];
  Line? _traceLine;

  @override
  void initState() {
    super.initState();
    _ensureLocationReady(); // asks once at launch
  }

  @override
  void dispose() {
    _posSub?.cancel();
    super.dispose();
  }

  Future<void> _ensureLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled && mounted) {
      await _askToEnableLocationServices();
    }

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

    if (granted) {
      _startPositionStream();
    } else {
      await _posSub?.cancel();
      _posSub = null;
      _lastUserLatLng = null;
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
      _lastUserLatLng = LatLng(p.latitude, p.longitude);
    }, onError: (e) {
      // swallow permission/other errors
    });
  }

  Future<void> _askToEnableLocationServices() async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enable location services'),
        content: const Text(
            'Location is turned off. Enable it to show your position on the map.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await Geolocator.openLocationSettings();
            },
            child: const Text('Open settings'),
          ),
        ],
      ),
    );
  }

  Future<bool> _ensurePermissionOnDemand() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    if (!granted && mounted) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Location permission needed'),
          content: const Text('Grant location permission in settings to use this feature.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await Geolocator.openAppSettings();
              },
              child: const Text('Open app settings'),
            ),
          ],
        ),
      );
    }

    setState(() {
      _hasLocationPermission = granted;
    });
    if (granted && _posSub == null) _startPositionStream();
    return granted;
  }

  Future<void> _onMapCreated(MaplibreMapController controller) async {
    _controller = controller;
    controller.onSymbolTapped.add(_onSymbolTapped);
  }

  Future<void> _centerOnUser2D() async {
    final ok = await _ensurePermissionOnDemand();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission not granted.')),
        );
      }
      return;
    }

    LatLng target = _lastUserLatLng ?? _initCam.target;
    if (_lastUserLatLng == null) {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
      );
      target = LatLng(pos.latitude, pos.longitude);
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

  Future<void> _addPin(LatLng at, String label) async {
    if (_controller == null) return;
    final symbol = await _controller!.addSymbol(
      SymbolOptions(
        geometry: at,
        iconImage: "marker-15",
        iconSize: 1.4,
        textField: label,
        textOffset: const Offset(0, 1.2),
        textHaloColor: "#0b0f14",
        textHaloWidth: 1.0,
      ),
    );
    _symbols.add(symbol);
  }

  Future<void> _drawOrUpdateTrace(List<LatLng> points) async {
    if (_controller == null || points.length < 2) return;
    if (_traceLine == null) {
      _traceLine = await _controller!.addLine(
        LineOptions(
          geometry: points,
          lineWidth: 4.0,
          lineOpacity: 0.9,
          lineColor: "#4F8DF7",
        ),
      );
    } else {
      await _controller!.updateLine(_traceLine!, LineOptions(geometry: points));
    }
  }

  void _onMapClick(Point<double> p, LatLng latLng) async {
    await _addPin(latLng, _formatLatLng(latLng));
    _showCoords(latLng);
  }

  void _onMapLongClick(Point<double> p, LatLng latLng) async {
    await _addPin(latLng, "Dropped");
    _showCoords(latLng);
  }

  void _onSymbolTapped(Symbol sym) {
    final pos = sym.options.geometry;
    if (pos != null) _showCoords(pos);
  }

  void _onCameraMove(CameraPosition pos) {
    _lastCam = pos;
  }

  void _onCameraIdle() {
    // If needed, you can react here; we just ensure _lastCam stays fresh.
  }

  void _showCoords(LatLng latLng) {
    final txt = "Lat: ${latLng.latitude.toStringAsFixed(6)}\n"
        "Lng: ${latLng.longitude.toStringAsFixed(6)}";
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF121820),
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            const Icon(Icons.place_outlined),
            const SizedBox(width: 8),
            const Text("Selected coordinates",
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.close),
            )
          ]),
          const SizedBox(height: 8),
          SelectableText(txt, style: const TextStyle(fontSize: 14)),
        ]),
      ),
    );
  }

  String _formatLatLng(LatLng l) =>
      "${l.latitude.toStringAsFixed(6)}, ${l.longitude.toStringAsFixed(6)}";

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
            myLocationRenderMode: MyLocationRenderMode.compass,
            myLocationTrackingMode: MyLocationTrackingMode.none,

            // Button-only perspective (avoid gesture confusion):
            rotateGesturesEnabled: true,
            tiltGesturesEnabled: false,

            initialCameraPosition: _initCam,
            compassEnabled: false,

            // Keep _lastCam in sync so toggles use the live center
            onCameraMove: _onCameraMove,
            onCameraIdle: _onCameraIdle,

            onMapClick: _onMapClick,
            onMapLongClick: _onMapLongClick,
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
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      floatingActionButton: _GlassPillButton(
        icon: LucideIcons.route,
        label: "Extend trace",
        onTap: () async {
          if (_symbols.isNotEmpty) {
            final last = _symbols.last.options.geometry!;
            final current = _traceLine?.options.geometry ?? [];
            await _drawOrUpdateTrace([...current, last]);
          }
        },
      ),
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

class _GlassPillButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _GlassPillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.black.withOpacity(0.35),
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
                Text(label,
                    style: const TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
    );
  }
}
