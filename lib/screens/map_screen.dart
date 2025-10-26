import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../services/location_service.dart';
import '../widgets/route_field_box.dart';
import '../widgets/glass_icon_button.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const _styleUrl = "https://tiles.openfreemap.org/styles/liberty";
  static const double _min3DZoom = 16.0;
  static const CameraPosition _initCam = CameraPosition(
    target: LatLng(50.087, 14.420),
    zoom: 13.0,
    tilt: 0.0,
    bearing: 0.0,
  );

  MapLibreMapController? _controller;
  bool _hasLocationPermission = false;
  CameraPosition _startCam = _initCam;
  CameraPosition _lastCam = _initCam;
  StreamSubscription<Position>? _posSub;
  LatLng? _lastUserLatLng;
  bool _is3DMode = false;
  bool _didAutoCenter = false;
  bool _expanded = false;
  static const double _collapsedMapFraction = 0.25; // ~16.8%
  static const double _bottomBarHeight = 100.0;
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ensureLocationReady();
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _fromCtrl.dispose();
    _toCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureLocationReady() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final granted = await LocationService.ensurePermission();
    if (!mounted) return;
    setState(() => _hasLocationPermission = granted);

    if (granted) {
      unawaited(_applyPersistedLastLocation());
      unawaited(_applyDeviceLastKnown());
      if (serviceEnabled) _startPositionStream();
    } else {
      await _posSub?.cancel();
      _posSub = null;
      _lastUserLatLng = null;
    }
  }

  Future<void> _applyPersistedLastLocation() async {
    final last = await LocationService.loadLastLatLng();
    if (last == null) return;
    final cam = CameraPosition(target: last, zoom: _initCam.zoom, tilt: 0.0, bearing: 0.0);
    if (!mounted) return;
    setState(() => _startCam = cam);
    if (_controller != null && !_didAutoCenter) {
      _lastCam = _startCam;
      await _controller!.moveCamera(CameraUpdate.newCameraPosition(_startCam));
    }
  }

  Future<void> _applyDeviceLastKnown() async {
    final last = await LocationService.lastKnownPosition();
    if (last == null) return;
    final cam = CameraPosition(
      target: LatLng(last.latitude, last.longitude),
      zoom: _initCam.zoom,
      tilt: 0.0,
      bearing: 0.0,
    );
    if (!mounted) return;
    setState(() => _startCam = cam);
    if (_controller != null && !_didAutoCenter) {
      _lastCam = _startCam;
      await _controller!.moveCamera(CameraUpdate.newCameraPosition(_startCam));
    }
  }

  void _startPositionStream() {
    _posSub?.cancel();
    _posSub = LocationService.positionStream(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10,
    ).listen((p) {
      final firstFix = _lastUserLatLng == null;
      _lastUserLatLng = LatLng(p.latitude, p.longitude);
      unawaited(LocationService.saveLastLatLng(_lastUserLatLng!));
      if (firstFix && !_didAutoCenter) {
        _didAutoCenter = true;
      }
      unawaited(_centerToUserKeepZoom());
    }, onError: (_) {});
  }

  Future<bool> _ensurePermissionOnDemand() async {
    final ok = await LocationService.ensurePermission();
    if (!mounted) return ok;
    setState(() => _hasLocationPermission = ok);
    if (ok && _posSub == null) _startPositionStream();
    return ok;
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;
    if (_startCam.target != _initCam.target && !_didAutoCenter) {
      _lastCam = _startCam;
      await _controller?.moveCamera(CameraUpdate.newCameraPosition(_startCam));
      if (mounted) setState(() {});
    }
  }

  Future<void> _centerOnUser2D() async {
    _didAutoCenter = true;
    final ok = await _ensurePermissionOnDemand();
    if (!ok) return;
    LatLng target = _lastUserLatLng ?? _startCam.target;
    if (_lastUserLatLng == null) {
      final pos = await LocationService.currentPosition(accuracy: LocationAccuracy.best);
      target = LatLng(pos.latitude, pos.longitude);
      unawaited(LocationService.saveLastLatLng(target));
    }
    _is3DMode = false;
    _lastCam = CameraPosition(target: target, zoom: 16.0, tilt: 0.0, bearing: 0.0);
    await _controller?.animateCamera(CameraUpdate.newCameraPosition(_lastCam));
    if (mounted) setState(() {});
  }

  Future<void> _toggle3D() async {
    final cam = _lastCam;
    final LatLng target = cam.target;
    if (!_is3DMode) {
      final double targetZoom = cam.zoom < _min3DZoom ? _min3DZoom : cam.zoom;
      _lastCam = CameraPosition(
        target: target,
        zoom: targetZoom + 0.2,
        bearing: cam.bearing,
        tilt: 60.0,
      );
      await _controller?.animateCamera(CameraUpdate.newCameraPosition(_lastCam));
      _is3DMode = true;
    } else {
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

  void _onCameraIdle() {}

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalH = constraints.maxHeight;
        final collapsedMapH = totalH * _collapsedMapFraction;
        final mapH = _expanded ? (totalH - _bottomBarHeight) : collapsedMapH;
        final lowerH = _expanded ? _bottomBarHeight : (totalH - collapsedMapH);

        return Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: mapH,
              width: double.infinity,
              color: const Color(0xFFFFFFFF),
              child: Stack(
                children: [
                  MapLibreMap(
                    onMapCreated: _onMapCreated,
                    styleString: _styleUrl,
                    myLocationEnabled: _hasLocationPermission,
                    myLocationRenderMode: _hasLocationPermission
                        ? MyLocationRenderMode.compass
                        : MyLocationRenderMode.normal,
                    myLocationTrackingMode: MyLocationTrackingMode.none,
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: false,
                    initialCameraPosition: _startCam,
                    compassEnabled: false,
                    onCameraMove: _onCameraMove,
                    onCameraIdle: _onCameraIdle,
                  ),
                  if (!_expanded)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          setState(() => _expanded = true);
                        },
                        child: const SizedBox.expand(),
                      ),
                    ),
                  if (_expanded)
                    SafeArea(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GlassIconButton(
                                icon: _is3DMode ? LucideIcons.undoDot : LucideIcons.box,
                                onTap: _toggle3D,
                              ),
                              const SizedBox(height: 10),
                              GlassIconButton(
                                icon: LucideIcons.locate,
                                onTap: _centerOnUser2D,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: lowerH,
              width: double.infinity,
              color: const Color(0xFFFFFFFF),
              child: _expanded
                  ? _ExpandedBottomBar(
                      onBackgroundTap: () {
                        setState(() => _expanded = false);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          _centerToUserKeepZoom();
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                        child: RouteFieldBox(
                          fromController: _fromCtrl,
                          toController: _toCtrl,
                        ),
                      ),
                    )
                  : SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RouteFieldBox(
                              fromController: _fromCtrl,
                              toController: _toCtrl,
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Suggestions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF000000),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Expanded(
                              child: _SuggestionsList(
                                items: const [
                                  _Suggestion(icon: LucideIcons.house, title: 'Home', subtitle: 'Save your home'),
                                  _Suggestion(icon: LucideIcons.building, title: 'Work', subtitle: 'Save your workplace'),
                                  _Suggestion(icon: LucideIcons.mapPin, title: 'Recent: Café', subtitle: 'Old Town, 1.2 km'),
                                  _Suggestion(icon: LucideIcons.mapPin, title: 'Recent: Station', subtitle: 'Central Station'),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _centerToUserKeepZoom() async {
    if (_controller == null || _lastUserLatLng == null) return;
    final cam = _lastCam;
    _lastCam = CameraPosition(
      target: _lastUserLatLng!,
      zoom: cam.zoom,
      tilt: _is3DMode ? 60.0 : 0.0,
      bearing: cam.bearing,
    );
    await _controller!.moveCamera(CameraUpdate.newCameraPosition(_lastCam));
  }
}

class _ExpandedBottomBar extends StatelessWidget {
  const _ExpandedBottomBar({
    required this.onBackgroundTap,
    required this.child,
  });

  final VoidCallback onBackgroundTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Background tap collapses the map
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onBackgroundTap,
            child: const SizedBox.expand(),
          ),
        ),
        // Field box on top; this is the only visible element over the expanded map
        Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: child,
          ),
        ),
      ],
    );
  }
}

class _Suggestion {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Suggestion({required this.icon, required this.title, required this.subtitle});
}

class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({required this.items});
  final List<_Suggestion> items;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final it = items[index];
        return _SuggestionTile(item: it);
      },
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.item});
  final _Suggestion item;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x0F000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x11000000)),
            ),
            alignment: Alignment.center,
            child: Icon(
              item.icon,
              size: 18,
              color: const Color(0xFF000000),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: Color(0xFF000000),
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    color: Color(0x99000000),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
