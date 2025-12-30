import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:transportia/widgets/time_selection_overlay.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vibration/vibration.dart';
import '../animations/curves.dart';
import '../providers/theme_provider.dart';
import '../models/route_field_kind.dart';
import '../models/stop_time.dart';
import '../models/time_selection.dart';
import '../models/trip_history_item.dart';
import '../screens/itinerary_list_screen.dart';
import '../screens/location_settings_screen.dart';
import '../screens/timetables_screen.dart';
import '../services/favorites_service.dart';
import '../services/location_service.dart';
import '../services/recent_trips_service.dart';
import '../services/stop_times_service.dart';
import '../services/transitous_map_service.dart';
import '../services/transitous_geocode_service.dart';
import '../theme/app_colors.dart';
import '../utils/color_utils.dart';
import '../utils/geo_utils.dart';
import '../utils/haptics.dart';
import '../utils/custom_page_route.dart';
import '../utils/leg_helper.dart';
import '../utils/time_utils.dart';
import '../widgets/pressable_highlight.dart';
import '../widgets/route_bottom_card.dart';
import '../widgets/route_suggestions_overlay.dart';
import '../widgets/validation_toast.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    this.deferInit = false,
    this.activateOnShow,
    this.onCollapseChanged,
    this.onCollapseProgressChanged,
    this.onOverlayVisibilityChanged,
    this.onTabChangeRequested,
    this.onTimetableRequested,
  });

  // If true, skip location permission/init until activated.
  final bool deferInit;
  // Optional external trigger to activate deferred init when revealed.
  final ValueListenable<bool>? activateOnShow;
  // Callback when the sheet collapse state changes
  final ValueChanged<bool>? onCollapseChanged;
  // Callback when the sheet collapse progress changes (0.0 = expanded, 1.0 = collapsed)
  final ValueChanged<double>? onCollapseProgressChanged;
  // Callback when overlays (time selection, route suggestions) are shown/hidden
  final ValueChanged<bool>? onOverlayVisibilityChanged;
  // Callback when a tab change is requested from a detail screen
  final ValueChanged<int>? onTabChangeRequested;
  // Callback when a timetable is requested for a stop
  final ValueChanged<TransitousLocationSuggestion>? onTimetableRequested;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
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
  bool _didAutoCenter = false;
  // Tracks if the draggable sheet is collapsed (map dominant)
  bool _isSheetCollapsed = false;
  double? _sheetTop; // dynamic top position of the sheet
  static const double _collapsedMapFraction = 0.25; // visible map when expanded
  static const double _bottomBarHeight = 116.0; // collapsed bar height
  final _fromCtrl = TextEditingController();
  final _toCtrl = TextEditingController();
  final FocusNode _fromFocus = FocusNode();
  final FocusNode _toFocus = FocusNode();
  late final AnimationController _snapCtrl;
  Animation<double>? _snapAnim;
  double? _snapTarget;
  bool _hasVibrator = false;
  bool _hasCustomVibration = false;
  Timer? _dragVibeTimer;
  Timer? _unfocusDebounceTimer;
  bool _didInitLocation = false;
  VoidCallback? _activateListener;
  TransitousLocationSuggestion? _fromSelection;
  TransitousLocationSuggestion? _toSelection;
  RouteFieldKind? _activeSuggestionField;
  List<TransitousLocationSuggestion> _suggestions =
      const <TransitousLocationSuggestion>[];
  bool _isFetchingSuggestions = false;
  int _suggestionRequestId = 0;
  bool _suppressFromListener = false;
  bool _suppressToListener = false;
  final LayerLink _routeFieldLink = LayerLink();
  final LayerLink _timeSelectionLayerLink = LayerLink();
  bool _focusEvaluationScheduled = false;
  Symbol? _fromSymbol;
  Symbol? _toSymbol;
  int _markerRefreshToken = 0;
  bool _didAddMarkerImages = false;
  LatLng? _longPressLatLng;
  final Map<RouteFieldKind, String> _pendingReverseGeocodeKeys = {};
  final Set<RouteFieldKind> _reverseGeocodeLoading = <RouteFieldKind>{};
  bool _showTimeSelectionOverlay = false;
  bool _isLongPressClosing = false;
  bool _suppressTimeSelectionReopen = false;
  TimeSelection _timeSelection = TimeSelection.now();
  int _tripsRefreshKey = 0;
  List<TripHistoryItem> _recentTrips = [];
  List<FavoritePlace> _favorites = [];
  bool _isSearching = false; // Prevent multiple search requests
  bool _isMapReady = false;
  Timer? _tripRefreshTimer;
  Timer? _tripRefreshDebounce;
  Timer? _stopRefreshDebounce;
  Timer? _vehicleAnimationTimer;
  int _tripRequestId = 0;
  int _stopRequestId = 0;
  int _stopTimesRequestId = 0;
  final Map<String, _VehicleMarker> _vehicles = {};
  final Map<String, MapStop> _visibleStops = {};
  final Set<String> _vehicleMarkerImages = {};
  bool _showStops = true;
  final Set<String> _stopMarkerImages = {};
  String? _stopMarkerImageId;
  Color? _stopAccentColor;
  bool _didAddStopsLayer = false;
  bool _didAddVehiclesLayer = false;
  MapStop? _selectedStop;
  bool _isStopOverlayClosing = false;
  bool _isStopTimesLoading = false;
  String? _stopTimesError;
  List<StopTime> _stopTimesPreview = [];

  static const Duration _tripWindowPast = Duration(minutes: 2);
  static const Duration _tripWindowFuture = Duration(minutes: 10);
  static const int _maxVehicleCount = 120;
  static const int _maxStopCount = 240;
  static const Duration _mapRefreshDebounce = Duration(milliseconds: 250);
  String? _lastTripsRequestKey;
  String? _lastStopsRequestKey;

  @override
  void initState() {
    super.initState();
    FavoritesService.favoritesListenable.addListener(_onFavoritesChanged);
    _favorites = FavoritesService.favoritesListenable.value;
    if (!widget.deferInit) {
      _ensureLocationReady();
      _didInitLocation = true;
    } else {
      _maybeAttachActivateListener();
    }
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _snapCtrl.addListener(() {
      final anim = _snapAnim;
      if (anim == null) return;
      final v = anim.value;
      if (_sheetTop != v) {
        setState(() => _sheetTop = v);
      }
    });
    _snapCtrl.addStatusListener((status) {
      if (status == AnimationStatus.completed && _snapTarget != null) {
        final target = _snapTarget!;
        // Resolve collapsed state only once snap animation finishes
        final collapsed =
            (target - ((_lastComputedCollapsedTop ?? target))).abs() < 1.0;
        if (collapsed != _isSheetCollapsed) {
          setState(() => _isSheetCollapsed = collapsed);
          widget.onCollapseChanged?.call(collapsed);
          if (!collapsed) _dismissLongPressOverlay(animated: false);
        }
        if (_isSheetCollapsed) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_selectionLatLngs().isNotEmpty) {
              unawaited(_fitSelectionBounds());
            } else {
              _centerToUserKeepZoom();
            }
          });
        }
        _hapticSnap();
        _snapTarget = null;
      }
    });
    _initHapticCaps();
    _fromFocus.addListener(_onAnyFieldFocus);
    _toFocus.addListener(_onAnyFieldFocus);
    _fromCtrl.addListener(_handleFromTextChanged);
    _toCtrl.addListener(_handleToTextChanged);
    unawaited(_loadRecentTrips());
    unawaited(FavoritesService.getFavorites());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final accent = AppColors.accentOf(context);
    if (_stopAccentColor?.value == accent.value) return;
    _stopAccentColor = accent;
    if (_isMapReady) {
      unawaited(_applyStopAccentColor());
    }
  }

  @override
  void dispose() {
    FavoritesService.favoritesListenable.removeListener(_onFavoritesChanged);
    _posSub?.cancel();
    _fromCtrl.removeListener(_handleFromTextChanged);
    _toCtrl.removeListener(_handleToTextChanged);
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    _stopDragRumble();
    _unfocusDebounceTimer?.cancel();
    _activateListener?.call();
    _activateListener = null;
    _tripRefreshTimer?.cancel();
    _tripRefreshDebounce?.cancel();
    _stopRefreshDebounce?.cancel();
    _vehicleAnimationTimer?.cancel();
    _controller?.onFeatureTapped.remove(_handleFeatureTapped);
    unawaited(_clearVehicleMarkers());
    unawaited(_clearStopMarkers());
    unawaited(_removeRouteSymbols());
    super.dispose();
    _snapCtrl.dispose();
  }

  void _onFavoritesChanged() {
    if (!mounted) return;
    setState(() {
      _favorites = FavoritesService.favoritesListenable.value;
    });
  }

  void _maybeAttachActivateListener() {
    final listenable = widget.activateOnShow;
    _activateListener?.call(); // no-op placeholder if set previously
    if (listenable != null) {
      void listener() {
        if (listenable.value) _activateIfNeeded();
      }

      listenable.addListener(listener);
      _activateListener = () => listenable.removeListener(listener);
      // If already true, activate immediately.
      if (listenable.value) _activateIfNeeded();
    }
  }

  void _activateIfNeeded() {
    if (_didInitLocation) return;
    _didInitLocation = true;
    _ensureLocationReady();
  }

  @override
  void didUpdateWidget(covariant MapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activateOnShow != widget.activateOnShow) {
      _activateListener?.call();
      _activateListener = null;
      if (widget.deferInit) {
        _maybeAttachActivateListener();
      }
    }
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
    final cam = CameraPosition(
      target: last,
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
    _posSub =
        LocationService.positionStream(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ).listen((p) {
          final firstFix = _lastUserLatLng == null;
          _lastUserLatLng = LatLng(p.latitude, p.longitude);
          unawaited(LocationService.saveLastLatLng(_lastUserLatLng!));
          if (firstFix && !_didAutoCenter) {
            _didAutoCenter = true;
            unawaited(_centerToUserKeepZoom());
          }
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
    controller.onFeatureTapped.add(_handleFeatureTapped);
    if (_startCam.target != _initCam.target && !_didAutoCenter) {
      _lastCam = _startCam;
      await _controller?.moveCamera(CameraUpdate.newCameraPosition(_startCam));
      if (mounted) setState(() {});
    }
  }

  void _onStyleLoaded() {
    _isMapReady = true;
    _didAddMarkerImages = false;
    _stopMarkerImages.clear();
    _stopMarkerImageId = null;
    _didAddStopsLayer = false;
    _didAddVehiclesLayer = false;
    _vehicleMarkerImages.clear();
    _lastTripsRequestKey = null;
    _lastStopsRequestKey = null;
    _tripRefreshTimer?.cancel();
    unawaited(_clearVehicleMarkers());
    unawaited(_clearStopMarkers());
    unawaited(_ensureMarkerImages());
    unawaited(_applyStopAccentColor());
    unawaited(_ensureStopsLayer());
    unawaited(_ensureVehicleLayer());
    unawaited(_refreshRouteMarkers());
    _vehicleAnimationTimer?.cancel();
    _vehicleAnimationTimer = Timer.periodic(
      const Duration(milliseconds: 80),
      (_) => _updateVehiclePositions(),
    );
    _tripRefreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _refreshTrips(force: true),
    );
    _scheduleTripRefresh();
    _scheduleStopRefresh();
    final controller = _controller;
    if (controller != null) {
      unawaited(controller.setSymbolIconAllowOverlap(true));
      unawaited(controller.setSymbolTextAllowOverlap(true));
    }
  }

  void _scheduleTripRefresh() {
    _tripRefreshDebounce?.cancel();
    _tripRefreshDebounce = Timer(_mapRefreshDebounce, () {
      unawaited(_refreshTrips());
    });
  }

  void _scheduleStopRefresh() {
    _stopRefreshDebounce?.cancel();
    _stopRefreshDebounce = Timer(_mapRefreshDebounce, () {
      unawaited(_refreshStops());
    });
  }

  Future<void> _centerOnUser2D() async {
    _didAutoCenter = true;
    final ok = await _ensurePermissionOnDemand();
    if (!ok) {
      final status = await Permission.locationWhenInUse.status;
      if (!mounted) return;
      if (status.isPermanentlyDenied) {
        Navigator.of(
          context,
        ).push(CustomPageRoute(child: const LocationSettingsScreen()));
      }
      return;
    }
    LatLng target = _lastUserLatLng ?? _startCam.target;
    if (_lastUserLatLng == null) {
      final pos = await LocationService.currentPosition(
        accuracy: LocationAccuracy.best,
      );
      target = LatLng(pos.latitude, pos.longitude);
      unawaited(LocationService.saveLastLatLng(target));
    }
    _lastCam = CameraPosition(
      target: target,
      zoom: 16.0,
      tilt: 0.0,
      bearing: 0.0,
    );
    await _controller?.animateCamera(CameraUpdate.newCameraPosition(_lastCam));
    if (mounted) setState(() {});
  }

  void _toggleStops() {
    _stopRequestId++;
    _stopRefreshDebounce?.cancel();
    setState(() => _showStops = !_showStops);
    _applyStopsLayerVisibility();
    if (_showStops) {
      _lastStopsRequestKey = null;
      _scheduleStopRefresh();
    } else {
      _dismissStopOverlay();
    }
  }

  void _onCameraMove(CameraPosition pos) {
    _lastCam = pos;
  }

  void _onCameraIdle() {
    _scheduleTripRefresh();
    _scheduleStopRefresh();
  }

  Future<void> _refreshTrips({bool force = false}) async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return;
    if (controller.isCameraMoving) return;
    final token = ++_tripRequestId;
    LatLngBounds bounds;
    try {
      bounds = await controller.getVisibleRegion();
    } catch (_) {
      return;
    }
    final viewKey = _viewKey(bounds, _lastCam.zoom);
    if (!force && viewKey == _lastTripsRequestKey) return;
    final now = DateTime.now().toUtc();
    final startTime = now.subtract(_tripWindowPast);
    final endTime = now.add(_tripWindowFuture);
    List<MapTripSegment> segments;
    try {
      segments = await TransitousMapService.fetchTripSegments(
        zoom: _lastCam.zoom,
        bounds: bounds,
        startTime: startTime,
        endTime: endTime,
      );
    } catch (_) {
      return;
    }
    if (!mounted || token != _tripRequestId) return;
    _lastTripsRequestKey = viewKey;
    await _updateVehiclesFromSegments(segments, now, token);
  }

  Future<void> _updateVehiclesFromSegments(
    List<MapTripSegment> segments,
    DateTime now,
    int token,
  ) async {
    final controller = _controller;
    if (controller == null) return;
    await _ensureVehicleLayer();
    final chosen = <String, _SelectedSegment>{};
    final maxVehicles = _maxVehiclesForZoom(_lastCam.zoom);
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      final dep = segment.departure?.toUtc();
      final arr = segment.arrival?.toUtc();
      if (dep == null || arr == null) continue;
      if (now.isBefore(dep) || now.isAfter(arr)) continue;
      final tripId = segment.tripId;
      final existing = chosen[tripId];
      if (existing == null || arr.isBefore(existing.arrival)) {
        chosen[tripId] = _SelectedSegment(
          segment: segment,
          colorIndex: i,
          arrival: arr,
        );
      }
      if (chosen.length >= maxVehicles) break;
    }

    final seenTripIds = chosen.keys.toSet();
    for (final entry in chosen.entries) {
      final tripId = entry.key;
      final selected = entry.value;
      final segData = _buildTripSegmentData(
        selected.segment,
        selected.colorIndex,
      );
      if (segData == null) continue;
      final visual = _vehicleMarkerVisual(segData);
      final imageId = await _ensureVehicleMarkerImage(visual, segData.color);
      if (imageId == null) continue;
      final existing = _vehicles[tripId];
      if (existing == null) {
        _vehicles[tripId] = _VehicleMarker(
          segmentData: segData,
          imageId: imageId,
        )..lastPosition = _positionAlongSegment(segData, now);
      } else {
        existing.segmentData = segData;
        existing.imageId = imageId;
      }
    }

    for (final entry in _vehicles.entries.toList()) {
      if (!seenTripIds.contains(entry.key)) {
        _vehicles.remove(entry.key);
      }
    }
    if (!mounted || token != _tripRequestId) return;
    unawaited(_pushVehicleSource(now));
  }

  void _updateVehiclePositions() {
    final controller = _controller;
    if (controller == null || _vehicles.isEmpty) return;
    if (controller.isCameraMoving) return;
    final now = DateTime.now().toUtc();
    final nowMs = now.millisecondsSinceEpoch;
    var anyChange = false;
    for (final entry in _vehicles.values) {
      final segData = entry.segmentData;
      final target = _positionAlongSegment(segData, now);
      final lastPosition = entry.lastPosition;
      if (lastPosition == null) {
        entry.lastPosition = target;
        entry.lastUpdateMs = nowMs;
        anyChange = true;
        continue;
      }

      final delta = coordinateDistanceInMeters(
        lastPosition.latitude,
        lastPosition.longitude,
        target.latitude,
        target.longitude,
      );
      if (delta < 0.7) continue;

      final lastUpdateMs = entry.lastUpdateMs ?? nowMs;
      final dtMs = (nowMs - lastUpdateMs).clamp(16, 500);
      final alpha = 1.0 - math.exp(-dtMs / 160.0);
      final smoothing = delta > 140 ? 1.0 : alpha.clamp(0.35, 0.9);
      entry.lastPosition = LatLng(
        lastPosition.latitude +
            (target.latitude - lastPosition.latitude) * smoothing,
        lastPosition.longitude +
            (target.longitude - lastPosition.longitude) * smoothing,
      );
      entry.lastUpdateMs = nowMs;
      anyChange = true;
    }
    if (anyChange) {
      unawaited(_pushVehicleSource(now));
    }
  }

  Future<void> _refreshStops() async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return;
    if (!_showStops) {
      _applyStopsLayerVisibility();
      return;
    }
    final token = ++_stopRequestId;
    LatLngBounds bounds;
    try {
      bounds = await controller.getVisibleRegion();
    } catch (_) {
      return;
    }
    final viewKey = _viewKey(bounds, _lastCam.zoom);
    if (viewKey == _lastStopsRequestKey) return;
    List<MapStop> stops;
    try {
      stops = await TransitousMapService.fetchStops(bounds: bounds);
    } catch (_) {
      return;
    }
    if (!mounted || token != _stopRequestId || !_showStops) return;
    _lastStopsRequestKey = viewKey;

    final maxStops = _maxStopsForZoom(_lastCam.zoom);
    if (stops.length > maxStops * 5) {
      stops = stops.take(maxStops * 5).toList();
    }
    stops = _selectStopsForView(stops, bounds, _lastCam.zoom);
    if (stops.length > maxStops) {
      stops = stops.take(maxStops).toList();
    }

    final nextStops = <String, MapStop>{
      for (final stop in stops) stop.id: stop,
    };
    final sameStops =
        nextStops.length == _visibleStops.length &&
        nextStops.keys.every(_visibleStops.containsKey);
    if (sameStops) return;
    _visibleStops
      ..clear()
      ..addAll(nextStops);
    await _ensureStopsLayer();
    if (token != _stopRequestId || !_showStops) return;
    await _setStopsSource(nextStops.values.toList());
    _applyStopsLayerVisibility();
  }

  Future<void> _clearStopMarkers() async {
    final controller = _controller;
    if (controller == null) return;
    _visibleStops.clear();
    if (!_didAddStopsLayer) return;
    try {
      await controller.setGeoJsonSource(
        _kStopsSourceId,
        _emptyFeatureCollection(),
      );
    } catch (_) {}
  }

  Future<void> _clearVehicleMarkers() async {
    final controller = _controller;
    if (controller == null) return;
    _vehicles.clear();
    if (!_didAddVehiclesLayer) return;
    try {
      await controller.setGeoJsonSource(
        _kVehiclesSourceId,
        _emptyFeatureCollection(),
      );
    } catch (_) {}
  }

  _TripSegmentData? _buildTripSegmentData(
    MapTripSegment segment,
    int colorIndex,
  ) {
    final dep = segment.departure?.toUtc();
    final arr = segment.arrival?.toUtc();
    if (dep == null || arr == null || !arr.isAfter(dep)) return null;
    final polyline = segment.polyline;
    if (polyline == null || polyline.isEmpty) return null;
    List<LatLng> points;
    try {
      points = _decodePolyline(polyline, 5);
    } catch (_) {
      return null;
    }
    if (points.length < 2) return null;
    final cumulative = List<double>.filled(points.length, 0);
    double total = 0;
    for (int i = 1; i < points.length; i++) {
      total += coordinateDistanceInMeters(
        points[i - 1].latitude,
        points[i - 1].longitude,
        points[i].latitude,
        points[i].longitude,
      );
      cumulative[i] = total;
    }
    if (total <= 0) return null;
    return _TripSegmentData(
      tripId: segment.tripId,
      label: _vehicleLabelForSegment(segment),
      mode: segment.mode ?? 'TRANSIT',
      departure: dep,
      arrival: arr,
      points: points,
      cumulative: cumulative,
      totalDistance: total,
      color: _segmentColorForIndex(segment, colorIndex),
    );
  }

  LatLng _positionAlongSegment(_TripSegmentData data, DateTime now) {
    final durationMs = data.arrival.millisecondsSinceEpoch -
        data.departure.millisecondsSinceEpoch;
    if (durationMs <= 0) return data.points.first;
    final t = (now.millisecondsSinceEpoch -
            data.departure.millisecondsSinceEpoch) /
        durationMs;
    final clamped = t.clamp(0.0, 1.0);
    final distance = clamped * data.totalDistance;
    return _pointAlong(data, distance);
  }

  LatLng _pointAlong(_TripSegmentData data, double targetMeters) {
    final points = data.points;
    final cumulative = data.cumulative;
    if (targetMeters <= 0) return points.first;
    if (targetMeters >= data.totalDistance) return points.last;
    var lo = 0;
    var hi = cumulative.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (cumulative[mid] < targetMeters) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    final i = math.max(1, lo);
    final d0 = cumulative[i - 1];
    final d1 = cumulative[i];
    final f = (d1 == d0) ? 0.0 : (targetMeters - d0) / (d1 - d0);
    final p0 = points[i - 1];
    final p1 = points[i];
    return LatLng(
      p0.latitude + (p1.latitude - p0.latitude) * f,
      p0.longitude + (p1.longitude - p0.longitude) * f,
    );
  }

  List<LatLng> _decodePolyline(String encoded, int precision) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;
    final double factor = math.pow(10, -precision).toDouble();

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat * factor, lng * factor));
    }
    return points;
  }

  Color _segmentColorForIndex(MapTripSegment segment, int index) {
    final parsed = parseHexColor(segment.routeColor);
    if (parsed != null) return parsed;
    if (segment.mode == 'WALK') {
      return const Color(0xFF666666);
    }
    return _defaultRouteColor(index);
  }

  String _vehicleLabelForSegment(MapTripSegment segment) {
    final display = segment.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final shortName = segment.routeShortName?.trim();
    if (shortName != null && shortName.isNotEmpty) return shortName;
    return segment.tripId;
  }

  Color _defaultRouteColor(int index) {
    final baseColor = AppColors.accentOf(context);
    final shadeFactors = [1.0, 0.7, 0.5, 0.3];
    final shadeFactor = shadeFactors[index % shadeFactors.length];

    return Color.fromARGB(
      255,
      ((baseColor.r * 255.0).round() * shadeFactor).round(),
      ((baseColor.g * 255.0).round() * shadeFactor).round(),
      ((baseColor.b * 255.0).round() * shadeFactor).round(),
    );
  }

  String _viewKey(LatLngBounds bounds, double zoom) {
    final south = math.min(
      bounds.southwest.latitude,
      bounds.northeast.latitude,
    );
    final north = math.max(
      bounds.southwest.latitude,
      bounds.northeast.latitude,
    );
    final west = math.min(
      bounds.southwest.longitude,
      bounds.northeast.longitude,
    );
    final east = math.max(
      bounds.southwest.longitude,
      bounds.northeast.longitude,
    );
    return [
      zoom.toStringAsFixed(2),
      south.toStringAsFixed(5),
      west.toStringAsFixed(5),
      north.toStringAsFixed(5),
      east.toStringAsFixed(5),
    ].join('|');
  }

  int _maxVehiclesForZoom(double zoom) {
    if (zoom >= 15.5) return _maxVehicleCount;
    if (zoom >= 14.0) return 100;
    if (zoom >= 12.5) return 80;
    return 60;
  }

  int _maxStopsForZoom(double zoom) {
    if (zoom >= 16.0) return _maxStopCount;
    if (zoom >= 14.5) return 200;
    if (zoom >= 13.0) return 160;
    if (zoom >= 12.0) return 120;
    return 90;
  }

  List<MapStop> _selectStopsForView(
    List<MapStop> stops,
    LatLngBounds bounds,
    double zoom,
  ) {
    if (stops.isEmpty) return stops;
    final deduped = <String, MapStop>{};
    for (final stop in stops) {
      final key =
          '${stop.lat.toStringAsFixed(6)}:${stop.lon.toStringAsFixed(6)}';
      final existing = deduped[key];
      if (existing == null) {
        deduped[key] = stop;
        continue;
      }
      final existingScore = existing.importance ?? 0.0;
      final candidateScore = stop.importance ?? 0.0;
      if (candidateScore > existingScore) {
        deduped[key] = stop;
      }
    }
    return deduped.values.toList();
  }

  String _colorToHex(Color color) {
    final r = (color.r * 255.0).round();
    final g = (color.g * 255.0).round();
    final b = (color.b * 255.0).round();
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }

  void _onTimeSelectionChanged(TimeSelection newSelection) {
    setState(() {
      _timeSelection = newSelection;
    });
  }

  void _notifyOverlayVisibility() {
    // Check if any overlay is currently visible
    final overlaysVisible =
        _showTimeSelectionOverlay || _activeSuggestionField != null;
    widget.onOverlayVisibilityChanged?.call(overlaysVisible);
  }

  void _openTimeSelectionOverlay() {
    if (_showTimeSelectionOverlay) return;
    _unfocusInputs();
    setState(() {
      _showTimeSelectionOverlay = true;
    });
    _notifyOverlayVisibility();
  }

  void _closeTimeSelectionOverlay() {
    if (!_showTimeSelectionOverlay) return;
    setState(() {
      _showTimeSelectionOverlay = false;
    });
    _notifyOverlayVisibility();
  }

  void _toggleTimeSelectionOverlay() {
    if (_showTimeSelectionOverlay) {
      _closeTimeSelectionOverlay();
    } else {
      _openTimeSelectionOverlay();
    }
  }

  void _handleTimeSelectionTapDown() {
    if (_showTimeSelectionOverlay) {
      _suppressTimeSelectionReopen = true;
      _closeTimeSelectionOverlay();
    }
  }

  void _handleTimeSelectionTapCancel() {
    _suppressTimeSelectionReopen = false;
  }

  void _handleTimeSelectionTap() {
    if (_suppressTimeSelectionReopen) {
      _suppressTimeSelectionReopen = false;
      return;
    }
    _toggleTimeSelectionOverlay();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop:
          !_fromFocus.hasFocus &&
          !_toFocus.hasFocus &&
          !_isSheetCollapsed &&
          !_showTimeSelectionOverlay &&
          _selectedStop == null &&
          _longPressLatLng == null,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (_selectedStop != null) {
            _dismissStopOverlay();
          } else if (_longPressLatLng != null) {
            _dismissLongPressOverlay();
          } else if (_showTimeSelectionOverlay) {
            _closeTimeSelectionOverlay();
          } else if (_fromFocus.hasFocus || _toFocus.hasFocus) {
            _unfocusInputs();
          } else {
            final expTop = _lastComputedExpandedTop;
            final colTop = _lastComputedCollapsedTop;
            if (expTop != null && colTop != null) {
              _animateTo(expTop, colTop);
              _stopDragRumble();
            }
          }
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final totalH = constraints.maxHeight;
          // Sheet anchors
          final double collapsedTop = math.max(0.0, totalH - _bottomBarHeight);
          final double expandedCandidate = totalH * _collapsedMapFraction;
          final double expandedTop = (expandedCandidate.clamp(
            0.0,
            collapsedTop,
          ));
          _lastComputedCollapsedTop = collapsedTop;
          _lastComputedExpandedTop = expandedTop;

          // Initialize and keep within bounds (e.g., on rotation)
          _sheetTop ??= expandedTop;
          _sheetTop = ((_sheetTop!).clamp(expandedTop, collapsedTop));
          final bool collapsed = ((_sheetTop! - collapsedTop).abs() < 1.0);
          if (collapsed != _isSheetCollapsed) {
            _isSheetCollapsed = collapsed;
            widget.onCollapseChanged?.call(collapsed);
          }

          final animDuration =
              Duration.zero; // we animate snaps via controller (smoother)

          final denom = (collapsedTop - expandedTop);
          final progress = denom <= 0.0
              ? 1.0
              : ((_sheetTop! - expandedTop) / denom).clamp(0.0, 1.0);

          // Notify progress for smooth navbar animation
          widget.onCollapseProgressChanged?.call(progress);

          final overlayWidth = math.max(0.0, constraints.maxWidth - 24);
          final showOverlay = _activeSuggestionField != null;
          final showLongPressOverlay =
              _longPressLatLng != null || _isLongPressClosing;
          final showStopOverlay = _selectedStop != null || _isStopOverlayClosing;
          const double pillRevealStart = 0.7;
          final double pillProgress =
              ((progress - pillRevealStart) / (1 - pillRevealStart)).clamp(
                0.0,
                1.0,
              );
          final double pillVisibility = Curves.easeOutCubic.transform(
            pillProgress,
          );
          final double pillYOffset = (1 - pillVisibility) * 32;
          return Stack(
            children: [
              // Map behind (isolated repaint)
              Positioned.fill(
                child: RepaintBoundary(
                  child: MapLibreMap(
                    onMapCreated: _onMapCreated,
                    onStyleLoadedCallback: _onStyleLoaded,
                    styleString: context.watch<ThemeProvider>().mapStyleUrl,
                    myLocationEnabled: _hasLocationPermission,
                    myLocationRenderMode: _hasLocationPermission
                        ? MyLocationRenderMode.compass
                        : MyLocationRenderMode.normal,
                    myLocationTrackingMode: MyLocationTrackingMode.none,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    initialCameraPosition: _startCam,
                    compassEnabled: false,
                    onCameraMove: _onCameraMove,
                    onCameraIdle: _onCameraIdle,
                    onMapClick: _onMapTap,
                    onMapLongClick: _onMapLongClick,
                    annotationConsumeTapEvents: const [AnnotationType.symbol],
                  ),
                ),
              ),

              if (_sheetTop != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: math.max(0.0, _sheetTop! - 46),
                  child: IgnorePointer(
                    ignoring: pillVisibility < 0.05,
                    child: Opacity(
                      opacity: pillVisibility,
                      child: Transform.translate(
                        offset: Offset(0, pillYOffset),
                        child: _MapControlPills(
                          showStops: _showStops,
                          onToggleStops: _toggleStops,
                          onLocate: _centerOnUser2D,
                        ),
                      ),
                    ),
                  ),
                ),

              if (showLongPressOverlay && _longPressLatLng != null)
                Positioned.fill(
                  child: _LongPressSelectionModal(
                    key: ValueKey(_longPressLatLng),
                    latLng: _longPressLatLng!,
                    isClosing: _isLongPressClosing,
                    onSelectFrom: () => _onLongPressChoice(RouteFieldKind.from),
                    onSelectTo: () => _onLongPressChoice(RouteFieldKind.to),
                    onDismissRequested: () => _dismissLongPressOverlay(),
                    onClosed: _handleLongPressOverlayClosed,
                  ),
                ),
              if (showStopOverlay && _selectedStop != null)
                Positioned.fill(
                  child: _StopSelectionModal(
                    key: ValueKey(_selectedStop!.id),
                    stop: _selectedStop!,
                    stopTimes: _stopTimesPreview,
                    isLoading: _isStopTimesLoading,
                    errorMessage: _stopTimesError,
                    isClosing: _isStopOverlayClosing,
                    onSelectFrom: () =>
                        _onStopChoice(RouteFieldKind.from, _selectedStop!),
                    onSelectTo: () =>
                        _onStopChoice(RouteFieldKind.to, _selectedStop!),
                    onViewTimetable: () => _openStopTimetable(_selectedStop!),
                    onDismissRequested: () => _dismissStopOverlay(),
                    onClosed: _handleStopOverlayClosed,
                  ),
                ),

              // Draggable white card anchored to bottom
              // The bottom card; position changes on drag. Snaps animate via controller above.
              AnimatedPositioned(
                duration: animDuration,
                curve: Curves.linear,
                left: 0,
                right: 0,
                top: _sheetTop!,
                bottom: 0,
                child: RepaintBoundary(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      BottomCard(
                        isCollapsed: _isSheetCollapsed,
                        collapseProgress: progress,
                        onHandleTap: () {
                          _unfocusInputs();
                          final target = _isSheetCollapsed
                              ? expandedTop
                              : collapsedTop;
                          _animateTo(target, collapsedTop);
                          _stopDragRumble();
                        },
                        onDragStart: () {
                          _unfocusInputs();
                          _snapCtrl.stop();
                          _startDragRumble();
                        },
                        onDragUpdate: (dy) {
                          final newTop = (_sheetTop! + dy).clamp(
                            expandedTop,
                            collapsedTop,
                          );
                          setState(() => _sheetTop = newTop);
                        },
                        onDragEnd: (velocityDy) {
                          final mid = (collapsedTop + expandedTop) / 2;
                          const vThresh = 700.0; // px/s
                          double target;
                          if (velocityDy.abs() > vThresh) {
                            target = velocityDy > 0
                                ? collapsedTop
                                : expandedTop;
                          } else {
                            target = (_sheetTop! > mid)
                                ? collapsedTop
                                : expandedTop;
                          }
                          _animateTo(target, collapsedTop);
                          _stopDragRumble();
                        },
                        fromCtrl: _fromCtrl,
                        toCtrl: _toCtrl,
                        fromFocusNode: _fromFocus,
                        toFocusNode: _toFocus,
                        showMyLocationDefault: _hasLocationPermission,
                        onUnfocus: _unfocusInputs,
                        onSwapRequested: _handleSwapRequested,
                        routeFieldLink: _routeFieldLink,
                        fromLoading: _isReverseGeocodeLoading(
                          RouteFieldKind.from,
                        ),
                        toLoading: _isReverseGeocodeLoading(RouteFieldKind.to),
                        fromSelection: _fromSelection,
                        toSelection: _toSelection,
                        onSearch: _search,
                        timeSelectionLayerLink: _timeSelectionLayerLink,
                        onTimeSelectionTap: _handleTimeSelectionTap,
                        onTimeSelectionTapDown: _handleTimeSelectionTapDown,
                        onTimeSelectionTapCancel: _handleTimeSelectionTapCancel,
                        timeSelection: _timeSelection,
                        recentTrips: _recentTrips,
                        onRecentTripTap: _onRecentTripTap,
                        tripsRefreshKey: _tripsRefreshKey,
                        favorites: _favorites,
                        onFavoriteTap: _onFavoriteTap,
                        hasLocationPermission: _hasLocationPermission,
                      ),
                      CompositedTransformFollower(
                        link: _routeFieldLink,
                        showWhenUnlinked: false,
                        targetAnchor: Alignment.bottomLeft,
                        followerAnchor: Alignment.topLeft,
                        offset: const Offset(0, 8),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final offsetTween = Tween<Offset>(
                              begin: const Offset(0, -0.05),
                              end: Offset.zero,
                            );
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: animation.drive(offsetTween),
                                child: child,
                              ),
                            );
                          },
                          child: !showOverlay
                              ? const SizedBox.shrink()
                              : RouteSuggestionsOverlay(
                                  key: const ValueKey(
                                    'route-suggestions-overlay',
                                  ),
                                  width: overlayWidth,
                                  activeField: _activeSuggestionField,
                                  fromController: _fromCtrl,
                                  toController: _toCtrl,
                                  suggestions: _suggestions,
                                  isLoading: _isFetchingSuggestions,
                                  onSuggestionTap: _onSuggestionSelected,
                                  onDismissRequest: _unfocusInputs,
                                ),
                        ),
                      ),
                      CompositedTransformFollower(
                        link: _timeSelectionLayerLink,
                        showWhenUnlinked: false,
                        targetAnchor: Alignment.bottomLeft,
                        followerAnchor: Alignment.topLeft,
                        offset: const Offset(0, 8),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          switchInCurve: Curves.easeOutCubic,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) {
                            final offsetTween = Tween<Offset>(
                              begin: const Offset(0, -0.05),
                              end: Offset.zero,
                            );
                            return FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: animation.drive(offsetTween),
                                child: child,
                              ),
                            );
                          },
                          child: !_showTimeSelectionOverlay
                              ? const SizedBox.shrink()
                              : TimeSelectionOverlay(
                                  width: overlayWidth,
                                  currentSelection: _timeSelection,
                                  onSelectionChanged: _onTimeSelectionChanged,
                                  onDismiss: _closeTimeSelectionOverlay,
                                  showDepartArriveToggle: true,
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _search(TimeSelection timeSelection) async {
    // Prevent multiple simultaneous search requests
    if (_isSearching) return;

    _unfocusInputs();
    final needsFrom = !_hasLocationPermission;
    final fromEmpty = _fromCtrl.text.trim().isEmpty;
    final toEmpty = _toCtrl.text.trim().isEmpty;
    final invalid = (needsFrom && fromEmpty) || toEmpty;
    if (invalid) {
      final msg = _hasLocationPermission
          ? 'Please enter a destination'
          : 'Please enter both locations';
      showValidationToast(context, msg);
      return;
    }

    setState(() => _isSearching = true);
    Haptics.mediumTick();

    Future<Position>? positionFuture;
    FutureOr<double> fromLatSource;
    FutureOr<double> fromLonSource;
    double? fromLatHistory;
    double? fromLonHistory;

    if (_fromSelection != null) {
      fromLatHistory = _fromSelection!.lat;
      fromLonHistory = _fromSelection!.lon;
    } else if (_lastUserLatLng != null) {
      fromLatHistory = _lastUserLatLng!.latitude;
      fromLonHistory = _lastUserLatLng!.longitude;
    } else {
      positionFuture = LocationService.currentPosition();
    }

    if (_toSelection == null) {
      showValidationToast(context, 'Please select a destination');
      setState(() => _isSearching = false);
      return;
    }

    final toLat = _toSelection!.lat;
    final toLon = _toSelection!.lon;

    if (positionFuture != null) {
      fromLatSource = positionFuture.then((position) => position.latitude);
      fromLonSource = positionFuture.then((position) => position.longitude);
    } else {
      fromLatSource = fromLatHistory!;
      fromLonSource = fromLonHistory!;
    }

    Navigator.of(context)
        .push(
          CupertinoPageRoute(
            builder: (_) => ItineraryListScreen(
              fromLat: fromLatSource,
              fromLon: fromLonSource,
              toLat: toLat,
              toLon: toLon,
              timeSelection: timeSelection,
              fromSelection: _fromSelection,
              toSelection: _toSelection,
            ),
          ),
        )
        .then((_) {
          _unfocusInputs();
          setState(() {
            _tripsRefreshKey++;
            _isSearching = false;
          });
          unawaited(_loadRecentTrips());
        });

    // Save trip to history without delaying navigation
    try {
      double resolvedFromLat;
      double resolvedFromLon;
      if (positionFuture != null) {
        final position = await positionFuture;
        resolvedFromLat = position.latitude;
        resolvedFromLon = position.longitude;
      } else {
        resolvedFromLat = fromLatHistory!;
        resolvedFromLon = fromLonHistory!;
      }

      final trip = TripHistoryItem.fromSelections(
        from: _fromSelection,
        to: _toSelection!,
        userLat: resolvedFromLat,
        userLon: resolvedFromLon,
      );
      await RecentTripsService.saveTrip(trip);
    } catch (_) {
      // Silently fail if history save fails
    }
  }

  Future<void> _centerToUserKeepZoom() async {
    if (_controller == null || _lastUserLatLng == null) return;
    final cam = _lastCam;
    _lastCam = CameraPosition(
      target: _lastUserLatLng!,
      zoom: cam.zoom,
      tilt: 0.0,
      bearing: cam.bearing,
    );
    await _controller!.moveCamera(CameraUpdate.newCameraPosition(_lastCam));
  }

  double? _lastComputedCollapsedTop;
  double? _lastComputedExpandedTop;
  void _animateTo(double target, double collapsedTop) {
    final begin = _sheetTop ?? target;
    _snapAnim = Tween<double>(begin: begin, end: target).animate(
      CurvedAnimation(parent: _snapCtrl, curve: SmallBackOutCurve(0.6)),
    );
    _snapCtrl
      ..stop()
      ..reset()
      ..forward();
    _snapTarget = target;
  }

  Future<void> _initHapticCaps() async {
    try {
      _hasVibrator = await Vibration.hasVibrator();
      _hasCustomVibration = await Vibration.hasCustomVibrationsSupport();
    } catch (_) {
      _hasVibrator = false;
      _hasCustomVibration = false;
    }
    if (!mounted) return;
    setState(() {});
  }

  void _startDragRumble() {
    _dragVibeTimer?.cancel();
    if (!_hasCustomVibration)
      return; // keep it subtle: only if custom supported
    _dragVibeTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      try {
        Vibration.vibrate(duration: 8, amplitude: 25);
      } catch (_) {}
    });
  }

  void _stopDragRumble() {
    _dragVibeTimer?.cancel();
    _dragVibeTimer = null;
  }

  void _handleFromTextChanged() => _handleTextChanged(RouteFieldKind.from);
  void _handleToTextChanged() => _handleTextChanged(RouteFieldKind.to);

  void _handleTextChanged(RouteFieldKind kind) {
    final isSuppressed = kind == RouteFieldKind.from
        ? _suppressFromListener
        : _suppressToListener;
    if (isSuppressed) return;
    final controller = _controllerFor(kind);
    final trimmed = controller.text.trim();
    final selection = _selectionFor(kind);
    if (selection != null && selection.name != trimmed) {
      _setSelection(kind, null, notify: true);
    }
    _requestSuggestions(kind, trimmed);
  }

  void _setSelection(
    RouteFieldKind kind,
    TransitousLocationSuggestion? value, {
    bool notify = false,
  }) {
    final current = kind == RouteFieldKind.from ? _fromSelection : _toSelection;
    if (identical(current, value)) {
      if (notify && mounted) setState(() {});
      return;
    }
    if (kind == RouteFieldKind.from) {
      _fromSelection = value;
    } else {
      _toSelection = value;
    }
    if (notify && mounted) setState(() {});
    unawaited(_refreshRouteMarkers());
  }

  TransitousLocationSuggestion? _selectionFor(RouteFieldKind kind) {
    return kind == RouteFieldKind.from ? _fromSelection : _toSelection;
  }

  TextEditingController _controllerFor(RouteFieldKind kind) {
    return kind == RouteFieldKind.from ? _fromCtrl : _toCtrl;
  }

  void _requestSuggestions(RouteFieldKind kind, String text) {
    final query = text.trim();
    if (query.length < 3) {
      if (_activeSuggestionField == kind &&
          (_suggestions.isNotEmpty || _isFetchingSuggestions)) {
        setState(() {
          _suggestions = const <TransitousLocationSuggestion>[];
          _isFetchingSuggestions = false;
        });
      }
      return;
    }
    final requestId = ++_suggestionRequestId;
    setState(() {
      _activeSuggestionField = kind;
      _isFetchingSuggestions = true;
    });
    // Notify overlay visibility change
    _notifyOverlayVisibility();
    final placeBias = _placeBiasLatLng();
    TransitousGeocodeService.fetchSuggestions(text: query, placeBias: placeBias)
        .then((results) {
          if (!mounted || requestId != _suggestionRequestId) return;
          setState(() {
            _suggestions = results;
            _isFetchingSuggestions = false;
          });
        })
        .catchError((_) {
          if (!mounted || requestId != _suggestionRequestId) return;
          setState(() {
            _suggestions = const <TransitousLocationSuggestion>[];
            _isFetchingSuggestions = false;
          });
        });
  }

  LatLng? _placeBiasLatLng() {
    if (!_hasLocationPermission) return null;
    if (_lastUserLatLng != null) return _lastUserLatLng;
    if (_startCam.target != _initCam.target) return _startCam.target;
    return null;
  }

  void _clearSuggestions() {
    if (_suggestions.isEmpty &&
        !_isFetchingSuggestions &&
        _activeSuggestionField == null) {
      return;
    }
    setState(() {
      _suggestions = const <TransitousLocationSuggestion>[];
      _isFetchingSuggestions = false;
      _activeSuggestionField = null;
    });
    // Notify overlay visibility change
    _notifyOverlayVisibility();
  }

  void _onSuggestionSelected(
    RouteFieldKind field,
    TransitousLocationSuggestion suggestion,
  ) {
    _setControllerText(field, suggestion.name);
    _setSelection(field, suggestion, notify: true);
    _unfocusInputs();
  }

  void _setControllerText(RouteFieldKind kind, String value) {
    if (kind == RouteFieldKind.from) {
      _suppressFromListener = true;
      _fromCtrl
        ..text = value
        ..selection = TextSelection.collapsed(offset: value.length);
      _suppressFromListener = false;
    } else {
      _suppressToListener = true;
      _toCtrl
        ..text = value
        ..selection = TextSelection.collapsed(offset: value.length);
      _suppressToListener = false;
    }
  }

  void _swapSelectionMetadata() {
    setState(() {
      final tmp = _fromSelection;
      _fromSelection = _toSelection;
      _toSelection = tmp;
    });
    unawaited(_refreshRouteMarkers());
  }

  bool _handleSwapRequested() {
    final fromText = _fromCtrl.text;
    final toText = _toCtrl.text;
    if (fromText.isEmpty && toText.isEmpty) {
      return false;
    }
    _suppressFromListener = true;
    _suppressToListener = true;
    _fromCtrl
      ..text = toText
      ..selection = TextSelection.collapsed(offset: toText.length);
    _toCtrl
      ..text = fromText
      ..selection = TextSelection.collapsed(offset: fromText.length);
    _suppressFromListener = false;
    _suppressToListener = false;
    _swapSelectionMetadata();
    if (_activeSuggestionField == RouteFieldKind.from) {
      _requestSuggestions(RouteFieldKind.from, _fromCtrl.text);
    } else if (_activeSuggestionField == RouteFieldKind.to) {
      _requestSuggestions(RouteFieldKind.to, _toCtrl.text);
    }
    _maybeFitSelectionsOnCollapsed();
    return true;
  }

  List<LatLng> _selectionLatLngs() {
    final points = <LatLng>[];
    final from = _effectiveFromLatLngForBounds();
    if (from != null) points.add(from);
    final to = _toSelection?.latLng;
    if (to != null) points.add(to);
    return points;
  }

  LatLng? _effectiveFromLatLngForBounds() {
    final selected = _fromSelection?.latLng;
    if (selected != null) return selected;
    if (!_hasLocationPermission) return null;
    if (_lastUserLatLng == null) return null;
    if (_fromCtrl.text.trim().isNotEmpty) return null;
    return _lastUserLatLng;
  }

  void _maybeFitSelectionsOnCollapsed() {
    if (!_isSheetCollapsed) return;
    unawaited(_fitSelectionBounds());
  }

  Future<void> _fitSelectionBounds() async {
    final controller = _controller;
    if (controller == null) return;
    final points = _selectionLatLngs();
    if (points.isEmpty) return;
    if (points.length == 1) {
      await controller.animateCamera(CameraUpdate.newLatLng(points.first));
      return;
    }
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points.skip(1)) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );
    final double bottomPadding = _isSheetCollapsed
        ? (_bottomBarHeight + 64.0)
        : 48.0;
    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        bounds,
        left: 48,
        top: 48,
        right: 48,
        bottom: bottomPadding,
      ),
    );
  }

  Future<void> _removeRouteSymbols() async {
    final controller = _controller;
    if (controller == null) return;
    final symbols = [_fromSymbol, _toSymbol];
    _fromSymbol = null;
    _toSymbol = null;
    for (final symbol in symbols) {
      if (symbol == null) continue;
      try {
        await controller.removeSymbol(symbol);
      } catch (_) {}
    }
  }

  Future<void> _refreshRouteMarkers() async {
    final controller = _controller;
    if (controller == null) return;
    await _ensureMarkerImages();
    final token = ++_markerRefreshToken;

    Future<void> removeSymbol(Symbol? symbol) async {
      if (symbol == null) return;
      try {
        await controller.removeSymbol(symbol);
      } catch (_) {}
    }

    final prevFrom = _fromSymbol;
    final prevTo = _toSymbol;
    _fromSymbol = null;
    _toSymbol = null;
    await removeSymbol(prevFrom);
    await removeSymbol(prevTo);

    Future<Symbol?> addSymbol(
      TransitousLocationSuggestion? selection,
      String imageId,
    ) async {
      if (selection == null) return null;
      try {
        return await controller.addSymbol(
          SymbolOptions(
            geometry: selection.latLng,
            iconImage: imageId,
            iconSize: 1.0,
            iconAnchor: 'bottom',
          ),
        );
      } catch (_) {
        return null;
      }
    }

    final newFrom = await addSymbol(_fromSelection, _kFromMarkerId);
    final newTo = await addSymbol(_toSelection, _kToMarkerId);

    if (_markerRefreshToken != token) {
      await removeSymbol(newFrom);
      await removeSymbol(newTo);
      return;
    }

    _fromSymbol = newFrom;
    _toSymbol = newTo;
    _maybeFitSelectionsOnCollapsed();
  }

  static const String _kFromMarkerId = 'route-marker-from';
  static const String _kToMarkerId = 'route-marker-to';
  static const String _kStopsSourceId = 'map-stops-source';
  static const String _kStopsLayerId = 'map-stops-layer';
  static const String _kVehiclesSourceId = 'map-vehicles-source';
  static const String _kVehiclesLayerId = 'map-vehicles-layer';

  Future<void> _ensureMarkerImages() async {
    if (_didAddMarkerImages) return;
    final controller = _controller;
    if (controller == null) return;
    Future<void> addMarker(String id, Color color, IconData icon) async {
      final image = await _buildMarkerImage(color, icon);
      await controller.addImage(id, image);
    }

    try {
      await addMarker(
        _kFromMarkerId,
        const Color(0xFF0B8F96),
        LucideIcons.mapPin,
      );
      await addMarker(_kToMarkerId, const Color(0xFFD04E37), LucideIcons.flag);
      _didAddMarkerImages = true;
    } catch (_) {
      _didAddMarkerImages = false;
    }
  }

  String _stopMarkerImageIdForColor(Color color) {
    final colorHex = _colorToHex(color).replaceAll('#', '');
    return 'map-stop-marker-$colorHex';
  }

  Future<String?> _ensureStopMarkerImageForColor(Color color) async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return null;
    final imageId = _stopMarkerImageIdForColor(color);
    if (_stopMarkerImages.contains(imageId)) {
      _stopMarkerImageId = imageId;
      return imageId;
    }
    try {
      final image = await _buildStopMarkerImage(color);
      await controller.addImage(imageId, image);
      _stopMarkerImages.add(imageId);
      _stopMarkerImageId = imageId;
      return imageId;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _buildMarkerImage(Color color, IconData icon) async {
    const double width = 72;
    const double height = 96;
    const double pointerHeight = 18;
    const double bubbleRadius = 22;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final bubbleCenter = Offset(
      width / 2,
      height - pointerHeight - bubbleRadius,
    );

    final shadowPaint = Paint()
      ..color = const Color(0x33000000)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(
      bubbleCenter + const Offset(0, 2),
      bubbleRadius + 3,
      shadowPaint,
    );

    final bodyPaint = Paint()..color = color;
    canvas.drawCircle(bubbleCenter, bubbleRadius, bodyPaint);

    final pointerPath = Path()
      ..moveTo(width / 2, height)
      ..lineTo(width / 2 - 10, height - pointerHeight)
      ..lineTo(width / 2 + 10, height - pointerHeight)
      ..close();
    canvas.drawPath(pointerPath, bodyPaint);

    final borderPaint = Paint()
      ..color = AppColors.solidWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(bubbleCenter, bubbleRadius - 1, borderPaint);

    final iconPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 28,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: AppColors.solidWhite,
        ),
      ),
    )..layout();

    iconPainter.paint(
      canvas,
      bubbleCenter - Offset(iconPainter.width / 2, iconPainter.height / 2),
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _buildStopMarkerImage(Color accentColor) async {
    const double size = 32;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    final outerPaint = Paint()
      ..color = AppColors.black.withValues(alpha: 0.2);
    canvas.drawCircle(center, size / 2, outerPaint);

    final ringPaint = Paint()..color = AppColors.white;
    canvas.drawCircle(center, size / 2 - 2, ringPaint);

    final innerPaint = Paint()..color = accentColor;
    canvas.drawCircle(center, size / 2 - 8, innerPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<void> _applyStopAccentColor() async {
    final color = _stopAccentColor ?? AppColors.accentOf(context);
    final imageId = await _ensureStopMarkerImageForColor(color);
    if (imageId == null || !_didAddStopsLayer) return;
    if (_visibleStops.isEmpty) return;
    await _setStopsSource(_visibleStops.values.toList());
  }

  _VehicleMarkerVisual _vehicleMarkerVisual(_TripSegmentData data) {
    final trimmed = data.label.trim();
    final condensed = trimmed.replaceAll(RegExp(r'\s+'), '');
    if (condensed.isNotEmpty && condensed.length <= 4) {
      return _VehicleMarkerVisual.text(condensed);
    }
    return _VehicleMarkerVisual.icon(getLegIcon(data.mode));
  }

  String _vehicleMarkerImageId(_VehicleMarkerVisual visual, Color color) {
    final colorHex = _colorToHex(color).replaceAll('#', '');
    final rawKey = visual.text ?? 'icon-${visual.icon?.codePoint ?? 0}';
    final key = rawKey.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '');
    return 'vehicle-$colorHex-$key';
  }

  Future<String?> _ensureVehicleMarkerImage(
    _VehicleMarkerVisual visual,
    Color color,
  ) async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return null;
    final imageId = _vehicleMarkerImageId(visual, color);
    if (_vehicleMarkerImages.contains(imageId)) return imageId;
    try {
      final image = await _buildVehicleMarkerImage(visual, color);
      await controller.addImage(imageId, image);
      _vehicleMarkerImages.add(imageId);
      return imageId;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List> _buildVehicleMarkerImage(
    _VehicleMarkerVisual visual,
    Color color,
  ) async {
    const double size = 44;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(size / 2, size / 2);

    final fillPaint = Paint()..color = color;
    canvas.drawCircle(center, size / 2 - 2, fillPaint);

    final strokePaint = Paint()
      ..color = AppColors.solidWhite
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawCircle(center, size / 2 - 3, strokePaint);

    if (visual.text != null) {
      final text = visual.text!.toUpperCase();
      final fontSize = text.length <= 2 ? 16.5 : 14.0;
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: text,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            color: AppColors.solidWhite,
          ),
        ),
      )..layout();
      painter.paint(
        canvas,
        center - Offset(painter.width / 2, painter.height / 2),
      );
    } else if (visual.icon != null) {
      final icon = visual.icon!;
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 22,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: AppColors.solidWhite,
          ),
        ),
      )..layout();
      painter.paint(
        canvas,
        center - Offset(painter.width / 2, painter.height / 2),
      );
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  List<Object> _vehicleIconSizeExpression() {
    return [
      Expressions.interpolate,
      ['linear'],
      [Expressions.zoom],
      12.0,
      1.0,
      14.0,
      1.25,
      16.0,
      1.6,
      18.0,
      2.05,
      20.0,
      2.45,
    ];
  }

  List<Object> _stopIconSizeExpression() {
    return [
      Expressions.interpolate,
      ['linear'],
      [Expressions.zoom],
      11.0,
      0.55,
      13.0,
      0.7,
      15.0,
      0.85,
      17.0,
      1.0,
    ];
  }

  Map<String, dynamic> _emptyFeatureCollection() {
    return const {'type': 'FeatureCollection', 'features': []};
  }

  Map<String, dynamic> _stopFeature(MapStop stop, String iconId) {
    return {
      'type': 'Feature',
      'id': stop.id,
      'properties': {
        'id': stop.id,
        'importance': stop.importance ?? 0.0,
        'iconId': iconId,
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [stop.lon, stop.lat],
      },
    };
  }

  Map<String, dynamic> _vehicleFeature(
    String tripId,
    _VehicleMarker marker,
    LatLng position,
  ) {
    return {
      'type': 'Feature',
      'id': tripId,
      'properties': {
        'id': tripId,
        'iconId': marker.imageId,
      },
      'geometry': {
        'type': 'Point',
        'coordinates': [position.longitude, position.latitude],
      },
    };
  }

  Future<void> _ensureStopsLayer() async {
    if (_didAddStopsLayer) return;
    final controller = _controller;
    if (controller == null || !_isMapReady) return;
    await _ensureVehicleLayer();
    final color = _stopAccentColor ?? AppColors.accentOf(context);
    final imageId = await _ensureStopMarkerImageForColor(color);
    if (imageId == null) return;
    try {
      await controller.addGeoJsonSource(
        _kStopsSourceId,
        _emptyFeatureCollection(),
        promoteId: 'id',
      );
      await controller.addSymbolLayer(
        _kStopsSourceId,
        _kStopsLayerId,
        SymbolLayerProperties(
          iconImage: [Expressions.get, 'iconId'],
          iconSize: _stopIconSizeExpression(),
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'center',
          symbolSortKey: [Expressions.get, 'importance'],
        ),
        belowLayerId: _didAddVehiclesLayer ? _kVehiclesLayerId : null,
        enableInteraction: true,
      );
      _didAddStopsLayer = true;
      _applyStopsLayerVisibility();
    } catch (_) {
      _didAddStopsLayer = false;
    }
  }

  Future<void> _ensureVehicleLayer() async {
    if (_didAddVehiclesLayer) return;
    final controller = _controller;
    if (controller == null || !_isMapReady) return;
    try {
      await controller.addGeoJsonSource(
        _kVehiclesSourceId,
        _emptyFeatureCollection(),
        promoteId: 'id',
      );
      await controller.addSymbolLayer(
        _kVehiclesSourceId,
        _kVehiclesLayerId,
        SymbolLayerProperties(
          iconImage: [Expressions.get, 'iconId'],
          iconSize: _vehicleIconSizeExpression(),
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'center',
          symbolSortKey: 1000,
        ),
        enableInteraction: false,
      );
      _didAddVehiclesLayer = true;
    } catch (_) {
      _didAddVehiclesLayer = false;
    }
  }

  void _applyStopsLayerVisibility() {
    final controller = _controller;
    if (controller == null || !_didAddStopsLayer) return;
    unawaited(controller.setLayerVisibility(_kStopsLayerId, _showStops));
  }

  Future<void> _setStopsSource(List<MapStop> stops) async {
    final controller = _controller;
    if (controller == null || !_didAddStopsLayer) return;
    final color = _stopAccentColor ?? AppColors.accentOf(context);
    final imageId =
        _stopMarkerImageId ?? await _ensureStopMarkerImageForColor(color);
    if (imageId == null) return;
    final features = stops.map((stop) => _stopFeature(stop, imageId)).toList();
    try {
      await controller.setGeoJsonSource(
        _kStopsSourceId,
        {'type': 'FeatureCollection', 'features': features},
      );
    } catch (_) {}
  }

  Future<void> _pushVehicleSource(DateTime now) async {
    final controller = _controller;
    if (controller == null || !_didAddVehiclesLayer) return;
    if (_vehicles.isEmpty) {
      try {
        await controller.setGeoJsonSource(
          _kVehiclesSourceId,
          _emptyFeatureCollection(),
        );
      } catch (_) {}
      return;
    }

    final features = <Map<String, dynamic>>[];
    for (final entry in _vehicles.entries) {
      final marker = entry.value;
      final position =
          marker.lastPosition ??
          _positionAlongSegment(marker.segmentData, now);
      features.add(_vehicleFeature(entry.key, marker, position));
    }
    try {
      await controller.setGeoJsonSource(
        _kVehiclesSourceId,
        {'type': 'FeatureCollection', 'features': features},
      );
    } catch (_) {}
  }

  void _onMapLongClick(math.Point<double> point, LatLng coordinate) {
    if (!_isSheetCollapsed) return;
    Haptics.mediumTick();
    _dismissStopOverlay();
    setState(() {
      _longPressLatLng = coordinate;
      _isLongPressClosing = false;
      _pendingReverseGeocodeKeys.clear();
    });
  }

  void _dismissLongPressOverlay({bool animated = true}) {
    if (_longPressLatLng == null) return;
    if (!animated) {
      setState(() {
        _longPressLatLng = null;
        _isLongPressClosing = false;
      });
      return;
    }
    if (_isLongPressClosing) return;
    setState(() => _isLongPressClosing = true);
  }

  void _handleLongPressOverlayClosed() {
    setState(() {
      _isLongPressClosing = false;
      _longPressLatLng = null;
    });
  }

  void _onLongPressChoice(RouteFieldKind kind) {
    final latLng = _longPressLatLng;
    if (latLng == null) return;
    Haptics.lightTick();
    _setReverseGeocodeLoading(kind, true);
    _dismissLongPressOverlay();
    _pendingReverseGeocodeKeys[kind] = _latLngKey(latLng);
    unawaited(_applyLongPressSelection(kind, latLng));
  }

  Future<void> _applyLongPressSelection(
    RouteFieldKind kind,
    LatLng latLng,
  ) async {
    TransitousLocationSuggestion? suggestion;
    try {
      suggestion = await TransitousGeocodeService.reverseGeocode(place: latLng);
    } catch (_) {
      suggestion = null;
    }
    if (!mounted) return;

    final pendingKey = _pendingReverseGeocodeKeys[kind];
    final thisKey = _latLngKey(latLng);
    if (pendingKey != thisKey) {
      if (pendingKey == null) {
        _setReverseGeocodeLoading(kind, false);
      }
      return;
    }
    _pendingReverseGeocodeKeys.remove(kind);

    suggestion ??= TransitousLocationSuggestion(
      id: 'reverse-${latLng.latitude.toStringAsFixed(6)}-${latLng.longitude.toStringAsFixed(6)}',
      name: _formatLatLngLabel(latLng),
      lat: latLng.latitude,
      lon: latLng.longitude,
      type: 'PLACE',
    );

    _setControllerText(kind, suggestion.name);
    _setSelection(kind, suggestion, notify: true);
    _clearSuggestions();
    _maybeFitSelectionsOnCollapsed();
    _setReverseGeocodeLoading(kind, false);
  }

  void _handleFeatureTapped(
    math.Point<double> point,
    LatLng coordinate,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId != _kStopsLayerId) return;
    final stop = _visibleStops[id];
    if (stop == null) return;
    Haptics.lightTick();
    _dismissLongPressOverlay();
    setState(() {
      _selectedStop = stop;
      _isStopOverlayClosing = false;
      _stopTimesPreview = [];
      _stopTimesError = null;
      _isStopTimesLoading = true;
    });
    unawaited(_loadStopTimesPreview(stop));
  }

  void _dismissStopOverlay({bool animated = true}) {
    if (_selectedStop == null) return;
    if (!animated) {
      _stopTimesRequestId++;
      setState(() {
        _selectedStop = null;
        _isStopOverlayClosing = false;
      });
      return;
    }
    if (_isStopOverlayClosing) return;
    _stopTimesRequestId++;
    setState(() => _isStopOverlayClosing = true);
  }

  void _handleStopOverlayClosed() {
    setState(() {
      _isStopOverlayClosing = false;
      _selectedStop = null;
      _stopTimesPreview = [];
      _stopTimesError = null;
      _isStopTimesLoading = false;
    });
  }

  void _onStopChoice(RouteFieldKind kind, MapStop stop) {
    Haptics.lightTick();
    final suggestion = _suggestionFromStop(stop);
    _setControllerText(kind, suggestion.name);
    _setSelection(kind, suggestion, notify: true);
    _clearSuggestions();
    _dismissStopOverlay();
    _maybeFitSelectionsOnCollapsed();
  }

  void _openStopTimetable(MapStop stop) {
    final stopId = stop.stopId;
    if (stopId == null || stopId.isEmpty) {
      showValidationToast(context, 'Timetable not available for this stop');
      return;
    }
    final suggestion = _suggestionFromStop(stop);
    _dismissStopOverlay();
    if (widget.onTimetableRequested != null) {
      widget.onTimetableRequested!(suggestion);
      widget.onTabChangeRequested?.call(1);
      return;
    }
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => TimetablesScreen(initialStop: suggestion),
      ),
    );
  }

  Future<void> _loadStopTimesPreview(MapStop stop) async {
    final stopId = stop.stopId;
    if (stopId == null || stopId.isEmpty) {
      if (!mounted) return;
      setState(() {
        _stopTimesPreview = [];
        _stopTimesError = 'Stop timetable unavailable.';
        _isStopTimesLoading = false;
      });
      return;
    }
    final requestId = ++_stopTimesRequestId;
    try {
      final response = await StopTimesService.fetchStopTimes(
        stopId: stopId,
        n: 6,
        startTime: DateTime.now(),
      );
      if (!mounted || requestId != _stopTimesRequestId) return;
      final deduped = _deduplicateStopTimes(response.stopTimes);
      final now = DateTime.now();
      final filtered = deduped
          .where((entry) => _stopTimeKey(entry) != null)
          .where((entry) {
            final time = _stopTimeKey(entry)!;
            return time.isAfter(now.subtract(const Duration(minutes: 1)));
          })
          .toList()
        ..sort((a, b) {
          final ta = _stopTimeKey(a)!;
          final tb = _stopTimeKey(b)!;
          return ta.compareTo(tb);
        });
      setState(() {
        _stopTimesPreview = filtered.take(3).toList();
        _stopTimesError = null;
        _isStopTimesLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _stopTimesRequestId) return;
      setState(() {
        _stopTimesPreview = [];
        _stopTimesError = 'Unable to load stop times.';
        _isStopTimesLoading = false;
      });
    }
  }

  List<StopTime> _deduplicateStopTimes(List<StopTime> stopTimes) {
    final seen = <String>{};
    final deduped = <StopTime>[];
    for (final stopTime in stopTimes) {
      final departure =
          stopTime.place.departure?.toIso8601String() ?? '';
      final key = '${stopTime.tripId}|$departure|${stopTime.headsign}';
      if (seen.add(key)) {
        deduped.add(stopTime);
      }
    }
    return deduped;
  }

  DateTime? _stopTimeKey(StopTime stopTime) {
    return stopTime.place.departure ??
        stopTime.place.scheduledDeparture ??
        stopTime.place.arrival ??
        stopTime.place.scheduledArrival;
  }

  TransitousLocationSuggestion _suggestionFromStop(MapStop stop) {
    return TransitousLocationSuggestion(
      id: stop.stopId ?? stop.id,
      name: stop.name,
      lat: stop.lat,
      lon: stop.lon,
      type: 'STOP',
    );
  }

  String _latLngKey(LatLng latLng) =>
      '${latLng.latitude.toStringAsFixed(6)},${latLng.longitude.toStringAsFixed(6)}';

  String _formatLatLngLabel(LatLng latLng) =>
      '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}';

  void _setReverseGeocodeLoading(RouteFieldKind kind, bool isLoading) {
    if (!mounted) return;
    final hasKind = _reverseGeocodeLoading.contains(kind);
    if (isLoading && hasKind) return;
    if (!isLoading && !hasKind) return;
    setState(() {
      if (isLoading) {
        _reverseGeocodeLoading.add(kind);
      } else {
        _reverseGeocodeLoading.remove(kind);
      }
    });
  }

  bool _isReverseGeocodeLoading(RouteFieldKind kind) =>
      _reverseGeocodeLoading.contains(kind);

  void _onMapTap(math.Point<double> point, LatLng coordinate) {
    _dismissStopOverlay();
    _dismissLongPressOverlay();
    if (_isSheetCollapsed) return;
    _unfocusInputs();
    _stopDragRumble();
    final colTop = _lastComputedCollapsedTop;
    final expTop = _lastComputedExpandedTop;
    if (colTop != null && expTop != null) {
      _animateTo(colTop, colTop);
    }
  }

  void _hapticSnap() {
    if (!_hasVibrator) return;
    try {
      if (_hasCustomVibration) {
        Vibration.vibrate(duration: 10, amplitude: 90);
      } else {
        Vibration.vibrate(duration: 10);
      }
    } catch (_) {}
  }

  void _onAnyFieldFocus() {
    if (_focusEvaluationScheduled) return;
    _focusEvaluationScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusEvaluationScheduled = false;
      _applyFocusState();
    });
  }

  void _applyFocusState() {
    if (!mounted) return;
    final hasFrom = _fromFocus.hasFocus;
    final hasTo = _toFocus.hasFocus;

    if (!hasFrom && !hasTo) {
      // Field lost focus - delay clearing suggestions to prevent flicker
      // if focus is regained quickly (e.g., when tapping same field)
      _unfocusDebounceTimer?.cancel();
      _unfocusDebounceTimer = Timer(const Duration(milliseconds: 100), () {
        if (!mounted) return;
        // Double-check focus state after delay
        if (!_fromFocus.hasFocus && !_toFocus.hasFocus) {
          _clearSuggestions();
        }
      });
      return;
    }

    // Field has focus - cancel any pending unfocus action
    _unfocusDebounceTimer?.cancel();
    _unfocusDebounceTimer = null;

    final field = hasFrom ? RouteFieldKind.from : RouteFieldKind.to;
    if (_activeSuggestionField != field) {
      setState(() => _activeSuggestionField = field);
    }
    _requestSuggestions(field, _controllerFor(field).text);
    if (_isSheetCollapsed) {
      final expTop = _lastComputedExpandedTop;
      final colTop = _lastComputedCollapsedTop;
      if (expTop != null && colTop != null) {
        _animateTo(expTop, colTop);
        _stopDragRumble();
      }
    }
  }

  void _unfocusInputs() {
    _unfocusDebounceTimer?.cancel();
    _unfocusDebounceTimer = null;
    FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
    _dismissStopOverlay();
    _dismissLongPressOverlay();
    _clearSuggestions();
  }

  Future<void> _loadRecentTrips() async {
    final trips = await RecentTripsService.getRecentTrips();
    if (!mounted) return;
    setState(() {
      _recentTrips = trips;
    });
  }

  void _onRecentTripTap(TripHistoryItem trip) {
    Haptics.lightTick();

    // Handle From field - leave empty if it was "My Location"
    if (trip.fromName != 'My Location') {
      final fromSuggestion = TransitousLocationSuggestion(
        id: 'history-from-${trip.fromLat}-${trip.fromLon}',
        name: trip.fromName,
        lat: trip.fromLat,
        lon: trip.fromLon,
        type: 'PLACE',
      );
      _setControllerText(RouteFieldKind.from, trip.fromName);
      _setSelection(RouteFieldKind.from, fromSuggestion, notify: true);
    } else {
      // Clear the from field for "My Location"
      _setControllerText(RouteFieldKind.from, '');
      _setSelection(RouteFieldKind.from, null, notify: true);
    }

    // Set the To field
    final toSuggestion = TransitousLocationSuggestion(
      id: 'history-to-${trip.toLat}-${trip.toLon}',
      name: trip.toName,
      lat: trip.toLat,
      lon: trip.toLon,
      type: 'PLACE',
    );
    _setControllerText(RouteFieldKind.to, trip.toName);
    _setSelection(RouteFieldKind.to, toSuggestion, notify: true);

    // Trigger search with current time (no time parameters)
    _search(TimeSelection.now());
  }

  void _onFavoriteTap(FavoritePlace favorite) {
    if (!_hasLocationPermission) {
      showValidationToast(
        context,
        "Location permission required to use favourites",
      );
      return;
    }

    Haptics.lightTick();

    // Clear from field for "My Location"
    _setControllerText(RouteFieldKind.from, '');
    _setSelection(RouteFieldKind.from, null, notify: true);

    // Set the To field to the favorite location
    final toSuggestion = TransitousLocationSuggestion(
      id: 'favorite-${favorite.lat}-${favorite.lon}',
      name: favorite.name,
      lat: favorite.lat,
      lon: favorite.lon,
      type: 'PLACE',
    );
    _setControllerText(RouteFieldKind.to, favorite.name);
    _setSelection(RouteFieldKind.to, toSuggestion, notify: true);

    // Trigger search with current time
    _search(TimeSelection.now());
  }
}

class _SelectedSegment {
  const _SelectedSegment({
    required this.segment,
    required this.colorIndex,
    required this.arrival,
  });

  final MapTripSegment segment;
  final int colorIndex;
  final DateTime arrival;
}

class _TripSegmentData {
  const _TripSegmentData({
    required this.tripId,
    required this.label,
    required this.mode,
    required this.departure,
    required this.arrival,
    required this.points,
    required this.cumulative,
    required this.totalDistance,
    required this.color,
  });

  final String tripId;
  final String label;
  final String mode;
  final DateTime departure;
  final DateTime arrival;
  final List<LatLng> points;
  final List<double> cumulative;
  final double totalDistance;
  final Color color;
}

class _VehicleMarker {
  _VehicleMarker({
    required this.segmentData,
    required this.imageId,
  });

  _TripSegmentData segmentData;
  String imageId;
  LatLng? lastPosition;
  int? lastUpdateMs;
}

class _VehicleMarkerVisual {
  const _VehicleMarkerVisual.text(this.text) : icon = null;
  const _VehicleMarkerVisual.icon(this.icon) : text = null;

  final String? text;
  final IconData? icon;
}

class _MapControlPills extends StatelessWidget {
  const _MapControlPills({
    required this.showStops,
    required this.onToggleStops,
    required this.onLocate,
  });

  final bool showStops;
  final VoidCallback onToggleStops;
  final VoidCallback onLocate;

  @override
  Widget build(BuildContext context) {
    final TextStyle stopsLabelStyle = TextStyle(
      color: showStops ? AppColors.accentOf(context) : AppColors.black,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        constraints: const BoxConstraints(maxWidth: 350),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MapControlChip(
              onTap: onToggleStops,
              width: 126,
              leading: Icon(
                showStops ? LucideIcons.mapPinOff : LucideIcons.mapPin,
                size: 16,
                color: showStops
                    ? AppColors.accentOf(context)
                    : AppColors.black,
              ),
              label: Text(
                showStops ? 'Hide Stops' : 'Show Stops',
                textAlign: TextAlign.center,
                style: stopsLabelStyle,
              ),
            ),
            const SizedBox(width: 8),
            _MapControlChip(
              onTap: onLocate,
              width: 104,
              leading: Icon(
                LucideIcons.locate,
                size: 16,
                color: AppColors.black,
              ),
              label: Text(
                'Locate',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapControlChip extends StatelessWidget {
  const _MapControlChip({
    required this.onTap,
    required this.leading,
    required this.label,
    this.width = 124,
  });

  final VoidCallback onTap;
  final Widget leading;
  final Widget label;
  final double width;

  @override
  Widget build(BuildContext context) {
    Widget content = _ChipContent(leading: leading, label: label);

    return PillButton(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      restingColor: AppColors.white,
      pressedColor: AppColors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(18),
      borderColor: AppColors.black.withValues(alpha: 0.1),
      child: SizedBox(width: width, child: content),
    );
  }
}

class _ChipContent extends StatelessWidget {
  const _ChipContent({required this.leading, required this.label});

  final Widget leading;
  final Widget label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(width: 20, child: Center(child: leading)),
        const SizedBox(width: 6),
        Expanded(
          child: Align(alignment: Alignment.center, child: label),
        ),
      ],
    );
  }
}

class _LongPressSelectionModal extends StatefulWidget {
  const _LongPressSelectionModal({
    super.key,
    required this.latLng,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.onDismissRequested,
    required this.onClosed,
    required this.isClosing,
  });

  final LatLng latLng;
  final VoidCallback onSelectFrom;
  final VoidCallback onSelectTo;
  final VoidCallback onDismissRequested;
  final VoidCallback onClosed;
  final bool isClosing;

  @override
  State<_LongPressSelectionModal> createState() =>
      _LongPressSelectionModalState();
}

class _LongPressSelectionModalState extends State<_LongPressSelectionModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _backdropOpacity;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed) {
            widget.onClosed();
          }
        });
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.linearToEaseOut,
      reverseCurve: Curves.easeInToLinear,
    );
    _scaleAnim = Tween<double>(begin: 1.1, end: 1.0).animate(_curve);
    _backdropOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_curve);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _LongPressSelectionModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isClosing && widget.isClosing) {
      if (_controller.value == 0.0) {
        widget.onClosed();
      } else {
        _controller.reverse();
      }
    } else if (oldWidget.latLng != widget.latLng && !widget.isClosing) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _backdropOpacity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismissRequested,
        child: Container(
          color: const Color(0xBF000000),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: ScaleTransition(
                scale: _scaleAnim,
                child: _LongPressModalCard(
                  latLng: widget.latLng,
                  onSelectFrom: widget.onSelectFrom,
                  onSelectTo: widget.onSelectTo,
                  onDismiss: widget.onDismissRequested,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LongPressModalCard extends StatelessWidget {
  const _LongPressModalCard({
    required this.latLng,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.onDismiss,
  });

  final LatLng latLng;
  final VoidCallback onSelectFrom;
  final VoidCallback onSelectTo;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final double maxWidth = math.min(size.width - 48.0, 340.0);
    const double iconBoxSize = 40.0;

    Widget segment(
      String label,
      IconData icon,
      VoidCallback onTap,
      BorderRadius radius,
      bool alignEnd,
    ) {
      return Expanded(
        child: PillButton(
          onTap: onTap,
          borderRadius: radius,
          restingColor: const Color(0x00000000),
          pressedColor: const Color(0x00000000),
          borderColor: const Color(0x00000000),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: FittedBox(
            alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: alignEnd
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              children: alignEnd
                  ? [
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(icon, size: 18, color: AppColors.black),
                    ]
                  : [
                      Icon(icon, size: 18, color: AppColors.black),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: AppColors.black,
                        ),
                      ),
                    ],
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 36,
              offset: Offset(0, 24),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.black.withValues(alpha: 0.07),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.mapPin,
                    size: 18,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: iconBoxSize,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Use this spot',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppColors.black,
                          ),
                        ),
                        Text(
                          '${latLng.latitude.toStringAsFixed(4)}, ${latLng.longitude.toStringAsFixed(4)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: AppColors.black.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Choose how to use this location:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.black.withValues(alpha: 0.07),
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  segment(
                    'Origin',
                    LucideIcons.arrowUpFromDot,
                    onSelectFrom,
                    const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                    false,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: const Color(0x33000000),
                  ),
                  segment(
                    'Destination',
                    LucideIcons.arrowDownToDot,
                    onSelectTo,
                    const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.center,
              child: PressableHighlight(
                onPressed: onDismiss,
                highlightColor: AppColors.accentOf(context),
                borderRadius: BorderRadius.circular(14),
                enableHaptics: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.x,
                      size: 18,
                      color: AppColors.accentOf(context),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Dismiss',
                      style: TextStyle(
                        color: AppColors.accentOf(context),
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopSelectionModal extends StatefulWidget {
  const _StopSelectionModal({
    super.key,
    required this.stop,
    required this.stopTimes,
    required this.isLoading,
    required this.errorMessage,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.onViewTimetable,
    required this.onDismissRequested,
    required this.onClosed,
    required this.isClosing,
  });

  final MapStop stop;
  final List<StopTime> stopTimes;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSelectFrom;
  final VoidCallback onSelectTo;
  final VoidCallback onViewTimetable;
  final VoidCallback onDismissRequested;
  final VoidCallback onClosed;
  final bool isClosing;

  @override
  State<_StopSelectionModal> createState() => _StopSelectionModalState();
}

class _StopSelectionModalState extends State<_StopSelectionModal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _curve;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _backdropOpacity;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 280),
        )..addStatusListener((status) {
          if (status == AnimationStatus.dismissed) {
            widget.onClosed();
          }
        });
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.linearToEaseOut,
      reverseCurve: Curves.easeInToLinear,
    );
    _scaleAnim = Tween<double>(begin: 1.06, end: 1.0).animate(_curve);
    _backdropOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(_curve);
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant _StopSelectionModal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isClosing && widget.isClosing) {
      if (_controller.value == 0.0) {
        widget.onClosed();
      } else {
        _controller.reverse();
      }
    } else if (oldWidget.stop.id != widget.stop.id && !widget.isClosing) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _backdropOpacity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismissRequested,
        child: Container(
          color: const Color(0xBF000000),
          alignment: Alignment.center,
          child: GestureDetector(
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ScaleTransition(
                scale: _scaleAnim,
                child: _StopModalCard(
                  stop: widget.stop,
                  stopTimes: widget.stopTimes,
                  isLoading: widget.isLoading,
                  errorMessage: widget.errorMessage,
                  onSelectFrom: widget.onSelectFrom,
                  onSelectTo: widget.onSelectTo,
                  onViewTimetable: widget.onViewTimetable,
                  onDismiss: widget.onDismissRequested,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StopModalCard extends StatelessWidget {
  const _StopModalCard({
    required this.stop,
    required this.stopTimes,
    required this.isLoading,
    required this.errorMessage,
    required this.onSelectFrom,
    required this.onSelectTo,
    required this.onViewTimetable,
    required this.onDismiss,
  });

  final MapStop stop;
  final List<StopTime> stopTimes;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSelectFrom;
  final VoidCallback onSelectTo;
  final VoidCallback onViewTimetable;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final double maxWidth = math.min(size.width - 48.0, 360.0);
    const double iconBoxSize = 40.0;

    Widget segment(
      String label,
      IconData icon,
      VoidCallback onTap,
      BorderRadius radius,
      bool alignEnd,
    ) {
      return Expanded(
        child: PillButton(
          onTap: onTap,
          borderRadius: radius,
          restingColor: const Color(0x00000000),
          pressedColor: const Color(0x00000000),
          borderColor: const Color(0x00000000),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: FittedBox(
            alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment:
                  alignEnd ? MainAxisAlignment.end : MainAxisAlignment.start,
              children: alignEnd
                  ? [
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(icon, size: 18, color: AppColors.black),
                    ]
                  : [
                      Icon(icon, size: 18, color: AppColors.black),
                      const SizedBox(width: 8),
                      Text(
                        label,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.fade,
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: AppColors.black,
                        ),
                      ),
                    ],
            ),
          ),
        ),
      );
    }

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 36,
              offset: Offset(0, 24),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: AppColors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.black.withValues(alpha: 0.07),
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    LucideIcons.mapPin,
                    size: 18,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: SizedBox(
                    height: iconBoxSize,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stop.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 17,
                            color: AppColors.black,
                          ),
                        ),
                        Text(
                          stop.stopId ?? 'Transit stop',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                            color: AppColors.black.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Next departures & arrivals',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.black.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            _StopTimesPreview(
              stopTimes: stopTimes,
              isLoading: isLoading,
              errorMessage: errorMessage,
            ),
            const SizedBox(height: 16),
            PressableHighlight(
              onPressed: onViewTimetable,
              highlightColor: AppColors.accentOf(context),
              borderRadius: BorderRadius.circular(14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    LucideIcons.clock,
                    size: 18,
                    color: AppColors.accentOf(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'View full timetable',
                    style: TextStyle(
                      color: AppColors.accentOf(context),
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Use this stop as:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AppColors.black.withValues(alpha: 0.07),
                ),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  segment(
                    'Origin',
                    LucideIcons.arrowUpFromDot,
                    onSelectFrom,
                    const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      bottomLeft: Radius.circular(14),
                    ),
                    false,
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    color: const Color(0x33000000),
                  ),
                  segment(
                    'Destination',
                    LucideIcons.arrowDownToDot,
                    onSelectTo,
                    const BorderRadius.only(
                      topRight: Radius.circular(14),
                      bottomRight: Radius.circular(14),
                    ),
                    true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Align(
              alignment: Alignment.center,
              child: PressableHighlight(
                onPressed: onDismiss,
                highlightColor: AppColors.accentOf(context),
                borderRadius: BorderRadius.circular(14),
                enableHaptics: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.x,
                      size: 18,
                      color: AppColors.accentOf(context),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Dismiss',
                      style: TextStyle(
                        color: AppColors.accentOf(context),
                        fontWeight: FontWeight.w500,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StopTimesPreview extends StatelessWidget {
  const _StopTimesPreview({
    required this.stopTimes,
    required this.isLoading,
    required this.errorMessage,
  });

  final List<StopTime> stopTimes;
  final bool isLoading;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const _StopTimesSkeleton();
    }
    if (errorMessage != null) {
      return Text(
        errorMessage!,
        style: TextStyle(
          color: AppColors.black.withValues(alpha: 0.6),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    if (stopTimes.isEmpty) {
      return Text(
        'No upcoming departures.',
        style: TextStyle(
          color: AppColors.black.withValues(alpha: 0.6),
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      );
    }
    return Column(
      children: [
        for (int i = 0; i < stopTimes.length; i++) ...[
          _StopTimePreviewRow(stopTime: stopTimes[i]),
          if (i != stopTimes.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _StopTimesSkeleton extends StatelessWidget {
  const _StopTimesSkeleton();

  @override
  Widget build(BuildContext context) {
    final baseColor = AppColors.black.withValues(alpha: 0.08);
    final highlightColor = AppColors.black.withValues(alpha: 0.04);
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: List.generate(
          3,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 2 ? 0 : 12),
            child: const _StopTimesSkeletonRow(),
          ),
        ),
      ),
    );
  }
}

class _StopTimesSkeletonRow extends StatelessWidget {
  const _StopTimesSkeletonRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 36,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.black.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 10,
                width: 140,
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              height: 10,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 10,
              width: 48,
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StopTimePreviewRow extends StatelessWidget {
  const _StopTimePreviewRow({required this.stopTime});

  final StopTime stopTime;

  @override
  Widget build(BuildContext context) {
    final routeColor =
        parseHexColor(stopTime.routeColor) ?? AppColors.black;
    final routeTextColor =
        parseHexColor(stopTime.routeTextColor) ?? AppColors.solidWhite;
    final arrival =
        formatTime(stopTime.place.arrival ?? stopTime.place.scheduledArrival);
    final departure =
        formatTime(stopTime.place.departure ?? stopTime.place.scheduledDeparture);
    final label = stopTime.displayName.isNotEmpty
        ? stopTime.displayName
        : stopTime.routeShortName;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 30),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          decoration: BoxDecoration(
            color: routeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: routeTextColor,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            stopTime.headsign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'Arr $arrival',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Dep $departure',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
