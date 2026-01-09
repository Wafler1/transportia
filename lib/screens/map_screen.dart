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
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timelines_plus/timelines_plus.dart';
import 'package:vibration/vibration.dart';
import '../animations/curves.dart';
import '../providers/theme_provider.dart';
import '../models/route_field_kind.dart';
import '../models/itinerary.dart';
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
import '../services/trip_details_service.dart';
import '../theme/app_colors.dart';
import '../utils/color_utils.dart';
import '../utils/duration_formatter.dart';
import '../utils/geo_utils.dart';
import '../utils/haptics.dart';
import '../utils/custom_page_route.dart';
import '../utils/leg_helper.dart';
import '../utils/time_utils.dart';
import '../widgets/custom_card.dart';
import '../widgets/info_chip.dart';
import '../widgets/pressable_highlight.dart';
import '../widgets/quick_button_picker_sheet.dart';
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
  static const double _tripFocusBottomBarHeight = 200.0;
  static const List<String> _mapStyleCycle = ['default', 'light', 'dark'];
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
  bool _didAddFocusedVehiclesLayer = false;
  bool _didAddFocusedStopsLayer = false;
  bool _didAddFocusedRouteLayer = false;
  Future<void>? _vehicleLayerInit;
  Future<void>? _focusedVehiclesLayerInit;
  Future<void>? _focusedStopsLayerInit;
  Future<void>? _focusedRouteLayerInit;
  Color? _focusedStopsColor;
  bool _isTripFocus = false;
  bool _isQuickSettings = false;
  bool _isTripFocusLoading = false;
  String? _tripFocusError;
  String? _focusedTripId;
  Itinerary? _focusedItinerary;
  bool _showStopsBeforeFocus = true;
  int _focusedTripRequestId = 0;
  final Map<String, _VehicleMarker> _focusedVehicles = {};
  final Map<String, MapStop> _focusedStops = {};
  final Set<String> _focusedRouteKeys = {};
  final Set<String> _focusedRouteColors = {};
  final Set<String> _focusedTripIds = {};
  MapStop? _selectedStop;
  bool _isStopOverlayClosing = false;
  bool _isStopTimesLoading = false;
  String? _stopTimesError;
  List<StopTime> _stopTimesPreview = [];
  bool _showVehicles = true;
  bool _hideNonRealtimeVehicles = false;
  _QuickButtonAction _quickButtonAction = _QuickButtonAction.toggleStops;
  final Map<_VehicleModeGroup, bool> _vehicleModeVisibility = {
    _VehicleModeGroup.train: true,
    _VehicleModeGroup.metro: true,
    _VehicleModeGroup.tram: true,
    _VehicleModeGroup.bus: true,
    _VehicleModeGroup.ferry: true,
    _VehicleModeGroup.lift: true,
    _VehicleModeGroup.other: true,
  };

  static const Duration _tripWindowPast = Duration(minutes: 2);
  static const Duration _tripWindowFuture = Duration(minutes: 10);
  static const int _maxVehicleCount = 120;
  static const int _maxStopCount = 240;
  static const double _focusedTransferZoomLevel = 16.5;
  static const double _focusedTransferDistanceThresholdMeters = 80.0;
  static const Duration _mapRefreshDebounce = Duration(milliseconds: 250);
  static const String _kShowStopsPrefKey = 'map_show_stops';
  static const String _kQuickButtonPrefKey = 'map_quick_button';
  static const String _kShowVehiclesPrefKey = 'map_show_vehicles';
  static const String _kHideNonRtPrefKey = 'map_hide_non_rt_vehicles';
  static const String _kShowTrainPrefKey = 'map_show_train';
  static const String _kShowMetroPrefKey = 'map_show_metro';
  static const String _kShowTramPrefKey = 'map_show_tram';
  static const String _kShowBusPrefKey = 'map_show_bus';
  static const String _kShowFerryPrefKey = 'map_show_ferry';
  static const String _kShowLiftPrefKey = 'map_show_lift';
  static const String _kShowOtherPrefKey = 'map_show_other';
  String? _lastTripsRequestKey;
  String? _lastStopsRequestKey;

  @override
  void initState() {
    super.initState();
    unawaited(_loadShowStopsPreference());
    unawaited(_loadQuickSettingsPreferences());
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
      if (status == AnimationStatus.completed ||
          status == AnimationStatus.dismissed) {
        _isBottomBarResizeAnimating = false;
      }
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
    if (_stopAccentColor?.toARGB32() == accent.toARGB32()) return;
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
    unawaited(_clearFocusedRoute());
    unawaited(_clearFocusedVehicles());
    unawaited(_clearFocusedStops());
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
    _didAddFocusedVehiclesLayer = false;
    _didAddFocusedStopsLayer = false;
    _didAddFocusedRouteLayer = false;
    _vehicleLayerInit = null;
    _focusedVehiclesLayerInit = null;
    _focusedStopsLayerInit = null;
    _focusedRouteLayerInit = null;
    _focusedStopsColor = null;
    _vehicleMarkerImages.clear();
    _focusedVehicles.clear();
    _focusedStops.clear();
    _focusedRouteKeys.clear();
    _focusedRouteColors.clear();
    _focusedTripIds.clear();
    _focusedTripId = null;
    _focusedItinerary = null;
    _isTripFocus = false;
    _isQuickSettings = false;
    _isTripFocusLoading = false;
    _tripFocusError = null;
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
      (_) => _handleTripRefreshTick(),
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
    if (_isTripFocus || !_showVehicles) return;
    _tripRefreshDebounce?.cancel();
    _tripRefreshDebounce = Timer(_mapRefreshDebounce, () {
      unawaited(_refreshTrips());
    });
  }

  void _scheduleStopRefresh() {
    if (_isTripFocus) return;
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
    _setShowStops(!_showStops);
  }

  void _toggleVehicles() {
    _setShowVehicles(!_showVehicles);
  }

  void _toggleRealtimeOnly() {
    _setHideNonRealtimeVehicles(!_hideNonRealtimeVehicles);
  }

  void _changeMapStyle() {
    unawaited(_cycleMapStyle());
  }

  Future<void> _cycleMapStyle() async {
    if (!mounted) return;
    final themeProvider = context.read<ThemeProvider>();
    final current = themeProvider.mapStyle;
    final index = _mapStyleCycle.indexOf(current);
    final nextIndex = (index + 1) % _mapStyleCycle.length;
    await themeProvider.setMapStyle(_mapStyleCycle[nextIndex]);
  }

  void _setShowStops(bool value, {bool persist = true}) {
    if (_showStops == value) return;
    _stopRequestId++;
    _stopRefreshDebounce?.cancel();
    setState(() => _showStops = value);
    if (persist) {
      unawaited(_persistShowStopsPreference(_showStops));
    }
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

  Future<void> _loadShowStopsPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getBool(_kShowStopsPrefKey);
    if (stored == null || !mounted) return;
    _setShowStops(stored, persist: false);
  }

  Future<void> _persistShowStopsPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowStopsPrefKey, value);
  }

  Future<void> _loadQuickSettingsPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final quickButtonKey = prefs.getString(_kQuickButtonPrefKey);
    final showVehicles = prefs.getBool(_kShowVehiclesPrefKey);
    final hideNonRt = prefs.getBool(_kHideNonRtPrefKey);
    final train = prefs.getBool(_kShowTrainPrefKey);
    final metro = prefs.getBool(_kShowMetroPrefKey);
    final tram = prefs.getBool(_kShowTramPrefKey);
    final bus = prefs.getBool(_kShowBusPrefKey);
    final ferry = prefs.getBool(_kShowFerryPrefKey);
    final lift = prefs.getBool(_kShowLiftPrefKey);
    final other = prefs.getBool(_kShowOtherPrefKey);
    if (!mounted) return;
    setState(() {
      _quickButtonAction = _quickButtonActionFromKey(quickButtonKey);
      if (showVehicles != null) {
        _showVehicles = showVehicles;
      }
      if (hideNonRt != null) {
        _hideNonRealtimeVehicles = hideNonRt;
      }
      if (train != null) {
        _vehicleModeVisibility[_VehicleModeGroup.train] = train;
      }
      if (metro != null) {
        _vehicleModeVisibility[_VehicleModeGroup.metro] = metro;
      }
      if (tram != null) {
        _vehicleModeVisibility[_VehicleModeGroup.tram] = tram;
      }
      if (bus != null) {
        _vehicleModeVisibility[_VehicleModeGroup.bus] = bus;
      }
      if (ferry != null) {
        _vehicleModeVisibility[_VehicleModeGroup.ferry] = ferry;
      }
      if (lift != null) {
        _vehicleModeVisibility[_VehicleModeGroup.lift] = lift;
      }
      if (other != null) {
        _vehicleModeVisibility[_VehicleModeGroup.other] = other;
      }
    });
    _applyVehiclesLayerVisibility();
    if (!_showVehicles) {
      unawaited(_clearVehicleMarkers());
    }
  }

  Future<void> _persistQuickButtonPreference(_QuickButtonAction action) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kQuickButtonPrefKey, _quickButtonActionKey(action));
  }

  Future<void> _persistShowVehiclesPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowVehiclesPrefKey, value);
  }

  Future<void> _persistHideNonRtPreference(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHideNonRtPrefKey, value);
  }

  Future<void> _persistVehicleModePreference(
    _VehicleModeGroup mode,
    bool value,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = switch (mode) {
      _VehicleModeGroup.train => _kShowTrainPrefKey,
      _VehicleModeGroup.metro => _kShowMetroPrefKey,
      _VehicleModeGroup.tram => _kShowTramPrefKey,
      _VehicleModeGroup.bus => _kShowBusPrefKey,
      _VehicleModeGroup.ferry => _kShowFerryPrefKey,
      _VehicleModeGroup.lift => _kShowLiftPrefKey,
      _VehicleModeGroup.other => _kShowOtherPrefKey,
    };
    await prefs.setBool(key, value);
  }

  void _setQuickButtonAction(_QuickButtonAction action) {
    if (_quickButtonAction == action) return;
    setState(() => _quickButtonAction = action);
    unawaited(_persistQuickButtonPreference(action));
  }

  void _setShowVehicles(bool value) {
    if (_showVehicles == value) return;
    setState(() => _showVehicles = value);
    unawaited(_persistShowVehiclesPreference(value));
    _applyVehiclesLayerVisibility();
    if (!_showVehicles) {
      _tripRefreshDebounce?.cancel();
      _lastTripsRequestKey = null;
      unawaited(_clearVehicleMarkers());
      return;
    }
    _lastTripsRequestKey = null;
    _scheduleTripRefresh();
  }

  void _setHideNonRealtimeVehicles(bool value) {
    if (_hideNonRealtimeVehicles == value) return;
    setState(() => _hideNonRealtimeVehicles = value);
    unawaited(_persistHideNonRtPreference(value));
    if (_isTripFocus) {
      unawaited(_refreshFocusedTripVehicles(force: true));
    } else {
      unawaited(_refreshTrips(force: true));
    }
  }

  void _setVehicleModeVisibility(_VehicleModeGroup mode, bool value) {
    if (_vehicleModeVisibility[mode] == value) return;
    setState(() => _vehicleModeVisibility[mode] = value);
    unawaited(_persistVehicleModePreference(mode, value));
    if (_isTripFocus) {
      unawaited(_refreshFocusedTripVehicles(force: true));
    } else {
      unawaited(_refreshTrips(force: true));
    }
  }

  String _quickButtonActionKey(_QuickButtonAction action) {
    return switch (action) {
      _QuickButtonAction.toggleStops => 'toggle_stops',
      _QuickButtonAction.toggleVehicles => 'toggle_vehicles',
      _QuickButtonAction.toggleRealtimeOnly => 'toggle_rt',
      _QuickButtonAction.changeMapStyle => 'change_map',
    };
  }

  _QuickButtonAction _quickButtonActionFromKey(String? value) {
    return switch (value) {
      'toggle_vehicles' => _QuickButtonAction.toggleVehicles,
      'toggle_rt' => _QuickButtonAction.toggleRealtimeOnly,
      'change_map' => _QuickButtonAction.changeMapStyle,
      _ => _QuickButtonAction.toggleStops,
    };
  }

  List<_QuickButtonOption> _quickButtonOptions() {
    return const [
      _QuickButtonOption(
        action: _QuickButtonAction.toggleStops,
        label: 'Toggle stops',
        icon: LucideIcons.mapPin,
        subtitle: 'Show or hide stops',
        enabled: true,
      ),
      _QuickButtonOption(
        action: _QuickButtonAction.toggleVehicles,
        label: 'Toggle vehicles',
        icon: LucideIcons.busFront,
        subtitle: 'Show or hide vehicles',
        enabled: true,
      ),
      _QuickButtonOption(
        action: _QuickButtonAction.toggleRealtimeOnly,
        label: 'Toggle Only RT',
        icon: LucideIcons.radio,
        subtitle: 'Show only real-time data',
        enabled: true,
      ),
      _QuickButtonOption(
        action: _QuickButtonAction.changeMapStyle,
        label: 'Change map',
        icon: LucideIcons.map,
        subtitle: 'Cycle map style',
        enabled: true,
      ),
    ];
  }

  _QuickButtonConfig _quickButtonConfig(BuildContext context) {
    switch (_quickButtonAction) {
      case _QuickButtonAction.toggleStops:
        final color = _showStops
            ? AppColors.accentOf(context)
            : AppColors.black;
        return _QuickButtonConfig(
          label: _showStops ? 'Hide Stops' : 'Show Stops',
          icon: _showStops ? LucideIcons.mapPinOff : LucideIcons.mapPin,
          color: color,
          onTap: _toggleStops,
        );
      case _QuickButtonAction.toggleVehicles:
        final color = _showVehicles
            ? AppColors.accentOf(context)
            : AppColors.black;
        return _QuickButtonConfig(
          label: _showVehicles ? 'Hide Transit' : 'Show Transit',
          icon: LucideIcons.busFront,
          color: color,
          onTap: _toggleVehicles,
        );
      case _QuickButtonAction.toggleRealtimeOnly:
        final color = _hideNonRealtimeVehicles
            ? AppColors.accentOf(context)
            : AppColors.black;
        return _QuickButtonConfig(
          label: _hideNonRealtimeVehicles ? 'RT Only' : 'All Data',
          icon: LucideIcons.radio,
          color: color,
          onTap: _toggleRealtimeOnly,
        );
      case _QuickButtonAction.changeMapStyle:
        return _QuickButtonConfig(
          label: 'Switch Map',
          icon: LucideIcons.map,
          color: AppColors.black,
          onTap: _changeMapStyle,
        );
    }
  }

  void _onCameraIdle() {
    _scheduleTripRefresh();
    _scheduleStopRefresh();
  }

  Future<void> _refreshTrips({bool force = false}) async {
    final controller = _controller;
    if (controller == null || !_isMapReady || _isTripFocus) return;
    if (!_showVehicles) {
      _applyVehiclesLayerVisibility();
      return;
    }
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

  void _handleTripRefreshTick() {
    if (_isTripFocus) {
      unawaited(_refreshFocusedTripVehicles(force: true));
      if (mounted) {
        setState(() {});
      }
    } else {
      if (_showVehicles) {
        unawaited(_refreshTrips(force: true));
      }
    }
  }

  Future<void> _refreshFocusedTripVehicles({bool force = false}) async {
    if (!_isTripFocus) return;
    final tripId = _focusedTripId;
    if (tripId == null || tripId.isEmpty) return;
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
    if (!force) {
      final viewKey = _viewKey(bounds, _lastCam.zoom);
      if (viewKey == _lastTripsRequestKey) return;
    }
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
    await _ensureFocusedVehiclesLayer();
    _lastTripsRequestKey = _viewKey(bounds, _lastCam.zoom);

    final chosen = <String, _SelectedSegment>{};
    final closestDelta = <String, Duration>{};
    for (int i = 0; i < segments.length; i++) {
      final segment = segments[i];
      if (!_matchesFocusedSegment(segment, tripId)) continue;
      if (!_passesVehicleFilters(segment)) continue;
      final dep = segment.departure?.toUtc();
      final arr = segment.arrival?.toUtc();
      if (dep == null || arr == null) continue;
      final key = segment.tripId;
      final segmentDelta = now.isBefore(dep)
          ? dep.difference(now)
          : now.isAfter(arr)
          ? now.difference(arr)
          : Duration.zero;
      final existing = chosen[key];
      final existingDelta = closestDelta[key];
      if (existing == null ||
          existingDelta == null ||
          segmentDelta < existingDelta ||
          (segmentDelta == existingDelta &&
              arr.isBefore(existing.arrival))) {
        chosen[key] = _SelectedSegment(
          segment: segment,
          colorIndex: i,
          arrival: arr,
        );
        closestDelta[key] = segmentDelta;
      }
    }

    final seenTripIds = chosen.keys.toSet();
    for (final entry in chosen.entries) {
      final segData = _buildTripSegmentData(
        entry.value.segment,
        entry.value.colorIndex,
      );
      if (segData == null) continue;
      final visual = _vehicleMarkerVisual(segData);
      final imageId = await _ensureVehicleMarkerImage(visual, segData.color);
      if (imageId == null) continue;
      final existing = _focusedVehicles[entry.key];
      if (existing == null) {
        _focusedVehicles[entry.key] = _VehicleMarker(
          segmentData: segData,
          imageId: imageId,
        )..lastPosition = _positionAlongSegment(segData, now);
      } else {
        existing.segmentData = segData;
        existing.imageId = imageId;
      }
    }

    for (final entry in _focusedVehicles.entries.toList()) {
      if (!seenTripIds.contains(entry.key)) {
        _focusedVehicles.remove(entry.key);
      }
    }

    if (!mounted || token != _tripRequestId) return;
    unawaited(_pushFocusedVehicleSource(now));
  }

  bool _matchesFocusedSegment(MapTripSegment segment, String tripId) {
    return segment.tripId == tripId;
  }

  bool _passesVehicleFilters(MapTripSegment segment) {
    if (_hideNonRealtimeVehicles && !segment.realTime) return false;
    final group = _vehicleModeGroupFor(segment.mode);
    return _vehicleModeVisibility[group] ?? true;
  }

  _VehicleModeGroup _vehicleModeGroupFor(String? mode) {
    final value = (mode ?? '').toUpperCase();
    if (value.contains('RAIL') || value == 'TRAIN') {
      return _VehicleModeGroup.train;
    }
    if (value == 'SUBWAY' || value == 'METRO') {
      return _VehicleModeGroup.metro;
    }
    if (value == 'TRAM' || value == 'STREETCAR') {
      return _VehicleModeGroup.tram;
    }
    if (value.contains('BUS') || value == 'COACH') {
      return _VehicleModeGroup.bus;
    }
    if (value == 'FERRY') {
      return _VehicleModeGroup.ferry;
    }
    if (value == 'GONDOLA' ||
        value == 'CABLE_CAR' ||
        value == 'FUNICULAR' ||
        value == 'LIFT') {
      return _VehicleModeGroup.lift;
    }
    return _VehicleModeGroup.other;
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
      if (!_passesVehicleFilters(segment)) continue;
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
    if (_isTripFocus) {
      _updateVehiclePositionsFor(_focusedVehicles, _pushFocusedVehicleSource);
    } else {
      if (!_showVehicles) return;
      _updateVehiclePositionsFor(_vehicles, _pushVehicleSource);
    }
  }

  void _updateVehiclePositionsFor(
    Map<String, _VehicleMarker> markers,
    Future<void> Function(DateTime) push,
  ) {
    final controller = _controller;
    if (controller == null || markers.isEmpty) return;
    final now = DateTime.now().toUtc();
    final nowMs = now.millisecondsSinceEpoch;
    var anyChange = false;
    for (final entry in markers.values) {
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
      unawaited(push(now));
    }
  }

  Future<void> _refreshStops() async {
    final controller = _controller;
    if (controller == null || !_isMapReady || _isTripFocus) return;
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

  Color _segmentColorForIndex(MapTripSegment segment, int _) {
    final parsed = parseHexColor(segment.routeColor?.trim());
    return parsed ?? _currentAccentColor();
  }

  Color _focusedRouteColor(Itinerary itinerary) {
    for (final leg in itinerary.legs) {
      if (leg.mode == 'WALK') continue;
      final parsed = parseHexColor(leg.routeColor);
      if (parsed != null) return parsed;
    }
    return _currentAccentColor();
  }

  Set<String> _buildFocusedRouteKeys(Itinerary itinerary) {
    final keys = <String>{};
    for (final leg in itinerary.legs) {
      if (leg.mode == 'WALK') continue;
      final display = leg.displayName?.trim();
      if (display != null && display.isNotEmpty) {
        keys.add(display);
      }
      final shortName = leg.routeShortName?.trim();
      if (shortName != null && shortName.isNotEmpty) {
        keys.add(shortName);
      }
      final longName = leg.routeLongName?.trim();
      if (longName != null && longName.isNotEmpty) {
        keys.add(longName);
      }
    }
    return keys;
  }

  Set<String> _buildFocusedRouteColors(Itinerary itinerary) {
    final colors = <String>{};
    for (final leg in itinerary.legs) {
      if (leg.routeColor == null) continue;
      final color = leg.routeColor!.trim();
      if (color.isNotEmpty) {
        colors.add(color.toUpperCase());
      }
    }
    return colors;
  }

  Set<String> _buildFocusedTripIds(Itinerary itinerary) {
    final tripIds = <String>{};
    for (final leg in itinerary.legs) {
      final id = leg.tripId?.trim();
      if (id != null && id.isNotEmpty) {
        tripIds.add(id);
      }
    }
    return tripIds;
  }

  String _vehicleLabelForSegment(MapTripSegment segment) {
    final display = segment.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final shortName = segment.routeShortName?.trim();
    if (shortName != null && shortName.isNotEmpty) return shortName;
    return segment.tripId;
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

  Color _currentAccentColor() {
    return ThemeProvider.instance?.accentColor ?? AppColors.accent;
  }

  void _onTimeSelectionChanged(TimeSelection newSelection) {
    setState(() {
      _timeSelection = newSelection;
    });
  }

  void _notifyOverlayVisibility() {
    // Route suggestions should hide the navbar; time selection should not.
    final overlaysVisible = _activeSuggestionField != null;
    widget.onOverlayVisibilityChanged?.call(overlaysVisible);
  }

  void _openTimeSelectionOverlay() {
    if (_showTimeSelectionOverlay) return;
    _unfocusInputs();
    setState(() {
      _showTimeSelectionOverlay = true;
    });
    _notifyOverlayVisibility();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Time selection',
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) {
        return TimeSelectionOverlay(
          currentSelection: _timeSelection,
          onSelectionChanged: _onTimeSelectionChanged,
          onDismiss: _closeTimeSelectionOverlay,
          showDepartArriveToggle: true,
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    ).then((_) {
      if (!mounted) return;
      if (_showTimeSelectionOverlay) {
        setState(() => _showTimeSelectionOverlay = false);
        _notifyOverlayVisibility();
      }
    });
  }

  void _closeTimeSelectionOverlay() {
    if (!_showTimeSelectionOverlay) return;
    Navigator.of(context, rootNavigator: true).maybePop();
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
          !_isTripFocus &&
          !_isQuickSettings &&
          !_fromFocus.hasFocus &&
          !_toFocus.hasFocus &&
          !_isSheetCollapsed &&
          !_showTimeSelectionOverlay &&
          _selectedStop == null &&
          _longPressLatLng == null,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          if (_isTripFocus) {
            _exitTripFocus();
          } else if (_isQuickSettings) {
            _closeQuickSettings();
          } else if (_selectedStop != null) {
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
          final double bottomBarHeight =
              _isTripFocus ? _tripFocusBottomBarHeight : _bottomBarHeight;
          // Sheet anchors
          final double collapsedTop = math.max(0.0, totalH - bottomBarHeight);
          final double expandedCandidate = totalH * _collapsedMapFraction;
          final double expandedTop = (expandedCandidate.clamp(
            0.0,
            collapsedTop,
          ));
          _lastComputedCollapsedTop = collapsedTop;
          _lastComputedExpandedTop = expandedTop;
          _lastBottomBarHeight = bottomBarHeight;

          // Initialize and keep within bounds (e.g., on rotation)
          _sheetTop ??= expandedTop;
          if (_isBottomBarResizeAnimating) {
            if (_sheetTop! < expandedTop) {
              _sheetTop = expandedTop;
            }
          } else {
            _sheetTop = ((_sheetTop!).clamp(expandedTop, collapsedTop));
          }
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

              if (_sheetTop != null && !_isTripFocus && !_isQuickSettings)
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
                          quickButton: _quickButtonConfig(context),
                          onLocate: _centerOnUser2D,
                          onSettings: _openQuickSettings,
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
                    onStopTimeTap: _onStopTimeSelected,
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
                      _isTripFocus
                          ? _TripFocusBottomCard(
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
                              onBack: _exitTripFocus,
                              itinerary: _focusedItinerary,
                              isLoading: _isTripFocusLoading,
                              errorMessage: _tripFocusError,
                              bottomSpacer: bottomBarHeight,
                            )
                          : _isQuickSettings
                          ? _QuickSettingsBottomCard(
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
                              onBack: _closeQuickSettings,
                              bottomSpacer: bottomBarHeight,
                              quickButtonAction: _quickButtonAction,
                              quickButtonOptions: _quickButtonOptions(),
                              showVehicles: _showVehicles,
                              hideNonRealtime: _hideNonRealtimeVehicles,
                              showStops: _showStops,
                              vehicleModeVisibility: _vehicleModeVisibility,
                              onQuickButtonChanged: _setQuickButtonAction,
                              onShowVehiclesChanged: _setShowVehicles,
                              onHideNonRealtimeChanged:
                                  _setHideNonRealtimeVehicles,
                              onVehicleModeChanged: _setVehicleModeVisibility,
                              onShowStopsChanged: _setShowStops,
                              onOpenAllSettings: _openAllSettings,
                            )
                          : BottomCard(
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
                              toLoading: _isReverseGeocodeLoading(
                                RouteFieldKind.to,
                              ),
                              fromSelection: _fromSelection,
                              toSelection: _toSelection,
                              onSearch: _search,
                              timeSelectionLayerLink: _timeSelectionLayerLink,
                              onTimeSelectionTap: _handleTimeSelectionTap,
                              onTimeSelectionTapDown:
                                  _handleTimeSelectionTapDown,
                              onTimeSelectionTapCancel:
                                  _handleTimeSelectionTapCancel,
                              timeSelection: _timeSelection,
                              recentTrips: _recentTrips,
                              onRecentTripTap: _onRecentTripTap,
                              tripsRefreshKey: _tripsRefreshKey,
                              favorites: _favorites,
                              onFavoriteTap: _onFavoriteTap,
                              hasLocationPermission: _hasLocationPermission,
                            ),
                      if (!_isTripFocus && !_isQuickSettings)
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
  double? _lastBottomBarHeight;
  bool _isBottomBarResizeAnimating = false;
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

  void _animateCollapsedHeightChange(double newBottomBarHeight) {
    final lastTop = _lastComputedCollapsedTop;
    final lastHeight = _lastBottomBarHeight;
    if (lastTop == null || lastHeight == null) return;
    final currentTop = _sheetTop ?? lastTop;
    final isNearCollapsed =
        _isSheetCollapsed || (currentTop - lastTop).abs() < 8.0;
    if (!isNearCollapsed) return;
    final delta = newBottomBarHeight - lastHeight;
    if (delta.abs() < 0.5) return;
    final target = lastTop - delta;
    _isBottomBarResizeAnimating = true;
    _animateTo(target, target);
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
    if (_isTripFocus) return;
    unawaited(_fitSelectionBounds());
  }

  Future<void> _fitSelectionBounds() async {
    if (_isTripFocus) return;
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

  Future<void> _refreshRouteMarkers({bool allowFit = true}) async {
    final controller = _controller;
    if (controller == null) return;
    if (_isTripFocus) {
      await _removeRouteSymbols();
      return;
    }
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
    if (_isTripFocus) return;

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
    if (allowFit) {
      _maybeFitSelectionsOnCollapsed();
    }
  }

  static const String _kFromMarkerId = 'route-marker-from';
  static const String _kToMarkerId = 'route-marker-to';
  static const String _kStopsSourceId = 'map-stops-source';
  static const String _kStopsLayerId = 'map-stops-layer';
  static const String _kVehiclesSourceId = 'map-vehicles-source';
  static const String _kVehiclesLayerId = 'map-vehicles-layer';
  static const String _kFocusedVehiclesSourceId =
      'map-focused-vehicles-source';
  static const String _kFocusedVehiclesLayerId = 'map-focused-vehicles-layer';
  static const String _kFocusedStopsSourceId = 'map-focused-stops-source';
  static const String _kFocusedStopsLayerId = 'map-focused-stops-layer';
  static const String _kFocusedRouteSourceId = 'map-focused-route-source';
  static const String _kFocusedRouteLayerId = 'map-focused-route-layer';

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
    if (imageId == null) return;
    if (_didAddStopsLayer && _visibleStops.isNotEmpty) {
      await _setStopsSource(_visibleStops.values.toList());
    }
    if (_didAddFocusedStopsLayer && _focusedStops.isNotEmpty) {
      await _setFocusedStopsSource(_focusedStops.values.toList());
    }
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
    final inFlight = _vehicleLayerInit;
    if (inFlight != null) return inFlight;
    final completer = Completer<void>();
    _vehicleLayerInit = completer.future;
    final controller = _controller;
    try {
      if (controller == null || !_isMapReady) return;
      Set<String> sourceIds;
      Set<String> layerIds;
      try {
        sourceIds = (await controller.getSourceIds()).cast<String>().toSet();
        layerIds = (await controller.getLayerIds()).cast<String>().toSet();
      } catch (_) {
        return;
      }
      final hasSource = sourceIds.contains(_kVehiclesSourceId);
      final hasLayer = layerIds.contains(_kVehiclesLayerId);
      if (hasSource && hasLayer) {
        _didAddVehiclesLayer = true;
        _applyVehiclesLayerVisibility();
        return;
      }
      if (!hasSource) {
        await controller.addGeoJsonSource(
          _kVehiclesSourceId,
          _emptyFeatureCollection(),
          promoteId: 'id',
        );
      }
      if (hasLayer) {
        _didAddVehiclesLayer = true;
        _applyVehiclesLayerVisibility();
        return;
      }
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
        enableInteraction: true,
      );
      _didAddVehiclesLayer = true;
      _applyVehiclesLayerVisibility();
    } catch (_) {
      _didAddVehiclesLayer = false;
    } finally {
      _vehicleLayerInit = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  Future<void> _ensureFocusedVehiclesLayer() async {
    if (_didAddFocusedVehiclesLayer) return;
    final inFlight = _focusedVehiclesLayerInit;
    if (inFlight != null) return inFlight;
    final completer = Completer<void>();
    _focusedVehiclesLayerInit = completer.future;
    final controller = _controller;
    try {
      if (controller == null || !_isMapReady) return;
      Set<String> sourceIds;
      Set<String> layerIds;
      try {
        sourceIds = (await controller.getSourceIds()).cast<String>().toSet();
        layerIds = (await controller.getLayerIds()).cast<String>().toSet();
      } catch (_) {
        return;
      }
      final hasSource = sourceIds.contains(_kFocusedVehiclesSourceId);
      final hasLayer = layerIds.contains(_kFocusedVehiclesLayerId);
      if (hasSource && hasLayer) {
        _didAddFocusedVehiclesLayer = true;
        _applyFocusedVehiclesLayerVisibility();
        return;
      }
      if (!hasSource) {
        await controller.addGeoJsonSource(
          _kFocusedVehiclesSourceId,
          _emptyFeatureCollection(),
          promoteId: 'id',
        );
      }
      if (hasLayer) {
        _didAddFocusedVehiclesLayer = true;
        _applyFocusedVehiclesLayerVisibility();
        return;
      }
      await controller.addSymbolLayer(
        _kFocusedVehiclesSourceId,
        _kFocusedVehiclesLayerId,
        SymbolLayerProperties(
          iconImage: [Expressions.get, 'iconId'],
          iconSize: _vehicleIconSizeExpression(),
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'center',
          symbolSortKey: 1200,
        ),
        enableInteraction: true,
      );
      _didAddFocusedVehiclesLayer = true;
      _applyFocusedVehiclesLayerVisibility();
    } catch (_) {
      _didAddFocusedVehiclesLayer = false;
    } finally {
      _focusedVehiclesLayerInit = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  Future<void> _ensureFocusedStopsLayer() async {
    if (_didAddFocusedStopsLayer) return;
    final inFlight = _focusedStopsLayerInit;
    if (inFlight != null) return inFlight;
    final completer = Completer<void>();
    _focusedStopsLayerInit = completer.future;
    final controller = _controller;
    try {
      if (controller == null || !_isMapReady) return;
      await _ensureFocusedVehiclesLayer();
      final color = _stopAccentColor ?? AppColors.accentOf(context);
      final imageId = await _ensureStopMarkerImageForColor(color);
      if (imageId == null) return;
      Set<String> sourceIds;
      Set<String> layerIds;
      try {
        sourceIds = (await controller.getSourceIds()).cast<String>().toSet();
        layerIds = (await controller.getLayerIds()).cast<String>().toSet();
      } catch (_) {
        return;
      }
      final hasSource = sourceIds.contains(_kFocusedStopsSourceId);
      final hasLayer = layerIds.contains(_kFocusedStopsLayerId);
      if (hasSource && hasLayer) {
        _didAddFocusedStopsLayer = true;
        _applyFocusedStopsLayerVisibility();
        return;
      }
      if (!hasSource) {
        await controller.addGeoJsonSource(
          _kFocusedStopsSourceId,
          _emptyFeatureCollection(),
          promoteId: 'id',
        );
      }
      if (hasLayer) {
        _didAddFocusedStopsLayer = true;
        _applyFocusedStopsLayerVisibility();
        return;
      }
      await controller.addSymbolLayer(
        _kFocusedStopsSourceId,
        _kFocusedStopsLayerId,
        SymbolLayerProperties(
          iconImage: [Expressions.get, 'iconId'],
          iconSize: _stopIconSizeExpression(),
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          iconAnchor: 'center',
          symbolSortKey: [Expressions.get, 'importance'],
        ),
        belowLayerId: _kFocusedVehiclesLayerId,
        enableInteraction: false,
      );
      _didAddFocusedStopsLayer = true;
      _applyFocusedStopsLayerVisibility();
    } catch (_) {
      _didAddFocusedStopsLayer = false;
    } finally {
      _focusedStopsLayerInit = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  Future<void> _ensureFocusedRouteLayer() async {
    if (_didAddFocusedRouteLayer) return;
    final inFlight = _focusedRouteLayerInit;
    if (inFlight != null) return inFlight;
    final completer = Completer<void>();
    _focusedRouteLayerInit = completer.future;
    final controller = _controller;
    try {
      if (controller == null || !_isMapReady) return;
      await _ensureFocusedStopsLayer();
      Set<String> sourceIds;
      Set<String> layerIds;
      try {
        sourceIds = (await controller.getSourceIds()).cast<String>().toSet();
        layerIds = (await controller.getLayerIds()).cast<String>().toSet();
      } catch (_) {
        return;
      }
      final hasSource = sourceIds.contains(_kFocusedRouteSourceId);
      final hasLayer = layerIds.contains(_kFocusedRouteLayerId);
      if (hasSource && hasLayer) {
        _didAddFocusedRouteLayer = true;
        _applyFocusedRouteVisibility();
        return;
      }
      if (!hasSource) {
        await controller.addGeoJsonSource(
          _kFocusedRouteSourceId,
          _emptyFeatureCollection(),
          promoteId: 'id',
        );
      }
      if (hasLayer) {
        _didAddFocusedRouteLayer = true;
        _applyFocusedRouteVisibility();
        return;
      }
      await controller.addLineLayer(
        _kFocusedRouteSourceId,
        _kFocusedRouteLayerId,
        LineLayerProperties(
          lineColor: [Expressions.get, 'color'],
          lineWidth: [
            Expressions.interpolate,
            ['linear'],
            [Expressions.zoom],
            11.0,
            2.2,
            14.0,
            3.4,
            17.0,
            4.6,
            20.0,
            6.0,
          ],
          lineJoin: 'round',
          lineCap: 'round',
        ),
        belowLayerId: _kFocusedStopsLayerId,
        enableInteraction: false,
      );
      _didAddFocusedRouteLayer = true;
      _applyFocusedRouteVisibility();
    } catch (_) {
      _didAddFocusedRouteLayer = false;
    } finally {
      _focusedRouteLayerInit = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  void _applyStopsLayerVisibility() {
    final controller = _controller;
    if (controller == null || !_didAddStopsLayer) return;
    unawaited(controller.setLayerVisibility(_kStopsLayerId, _showStops));
  }

  void _applyVehiclesLayerVisibility() {
    final controller = _controller;
    if (controller == null || !_didAddVehiclesLayer) return;
    unawaited(
      controller.setLayerVisibility(
        _kVehiclesLayerId,
        !_isTripFocus && _showVehicles,
      ),
    );
  }

  void _applyFocusedVehiclesLayerVisibility() {
    final controller = _controller;
    if (controller == null || !_didAddFocusedVehiclesLayer) return;
    unawaited(
      controller.setLayerVisibility(_kFocusedVehiclesLayerId, _isTripFocus),
    );
  }

  void _applyFocusedStopsLayerVisibility() {
    final controller = _controller;
    if (controller == null || !_didAddFocusedStopsLayer) return;
    unawaited(
      controller.setLayerVisibility(_kFocusedStopsLayerId, _isTripFocus),
    );
  }

  void _applyFocusedRouteVisibility() {
    final controller = _controller;
    if (controller == null || !_didAddFocusedRouteLayer) return;
    unawaited(
      controller.setLayerVisibility(_kFocusedRouteLayerId, _isTripFocus),
    );
  }

  Future<void> _setStopsSource(List<MapStop> stops) async {
    final controller = _controller;
    if (controller == null || !_didAddStopsLayer) return;
    final color = _stopAccentColor ?? AppColors.accentOf(context);
    final desiredId = _stopMarkerImageIdForColor(color);
    final imageId = _stopMarkerImageId == desiredId
        ? _stopMarkerImageId
        : await _ensureStopMarkerImageForColor(color);
    if (imageId == null) return;
    final features = stops.map((stop) => _stopFeature(stop, imageId)).toList();
    try {
      await controller.setGeoJsonSource(
        _kStopsSourceId,
        {'type': 'FeatureCollection', 'features': features},
      );
    } catch (_) {}
  }

  Future<void> _setFocusedStopsSource(List<MapStop> stops) async {
    final controller = _controller;
    if (controller == null || !_didAddFocusedStopsLayer) return;
    final color =
        _focusedStopsColor ??
        _stopAccentColor ??
        AppColors.accentOf(context);
    final desiredId = _stopMarkerImageIdForColor(color);
    final imageId = _stopMarkerImageId == desiredId
        ? _stopMarkerImageId
        : await _ensureStopMarkerImageForColor(color);
    if (imageId == null) return;
    final features = stops.map((stop) => _stopFeature(stop, imageId)).toList();
    try {
      await controller.setGeoJsonSource(
        _kFocusedStopsSourceId,
        {'type': 'FeatureCollection', 'features': features},
      );
    } catch (_) {}
  }

  Future<void> _setFocusedRoute(Itinerary itinerary) async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return;
    await _ensureFocusedRouteLayer();
    if (!_didAddFocusedRouteLayer) return;
    final features = <Map<String, dynamic>>[];
    for (int i = 0; i < itinerary.legs.length; i++) {
      final leg = itinerary.legs[i];
      final legColor =
          parseHexColor(leg.routeColor?.trim()) ??
          _currentAccentColor();
      final colorHex = _colorToHex(legColor);
      final geometry = leg.legGeometry;
      List<LatLng> points = [];
      if (geometry != null && geometry.points.isNotEmpty) {
        try {
          points = _decodePolyline(geometry.points, geometry.precision);
        } catch (_) {
          points = [];
        }
      }
      if (points.length < 2) {
        if (leg.fromLat != 0.0 ||
            leg.fromLon != 0.0 ||
            leg.toLat != 0.0 ||
            leg.toLon != 0.0) {
          points = [
            LatLng(leg.fromLat, leg.fromLon),
            LatLng(leg.toLat, leg.toLon),
          ];
        }
      }
      if (points.length < 2) continue;
      features.add({
        'type': 'Feature',
        'id': 'route-$i',
        'properties': {'color': colorHex},
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            for (final p in points) [p.longitude, p.latitude],
          ],
        },
      });
    }
    try {
      await controller.setGeoJsonSource(
        _kFocusedRouteSourceId,
        {'type': 'FeatureCollection', 'features': features},
      );
    } catch (_) {}
  }

  Future<void> _setFocusedStops(Itinerary itinerary) async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return;
    await _ensureFocusedStopsLayer();
    if (!_didAddFocusedStopsLayer) return;
    final stops = _buildFocusedStops(itinerary);
    _focusedStops
      ..clear()
      ..addAll(stops);
    if (_focusedStops.isEmpty) return;
    await _setFocusedStopsSource(_focusedStops.values.toList());
  }

  Map<String, MapStop> _buildFocusedStops(Itinerary itinerary) {
    final deduped = <String, MapStop>{};

    void addStop(String name, double lat, double lon, String? stopId) {
      if (name.trim().isEmpty) return;
      if (lat == 0.0 && lon == 0.0) return;
      final key = (stopId != null && stopId.isNotEmpty)
          ? stopId
          : '${lat.toStringAsFixed(6)}:${lon.toStringAsFixed(6)}';
      if (deduped.containsKey(key)) return;
      deduped[key] = MapStop(
        id: key,
        name: name,
        lat: lat,
        lon: lon,
        stopId: stopId,
      );
    }

    for (final leg in itinerary.legs) {
      addStop(leg.fromName, leg.fromLat, leg.fromLon, null);
      for (final stop in leg.intermediateStops) {
        addStop(stop.name, stop.lat, stop.lon, stop.stopId);
      }
      addStop(leg.toName, leg.toLat, leg.toLon, null);
    }
    return deduped;
  }

  Future<void> _fitCameraToFocusedItinerary(Itinerary itinerary) async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return;
    final points = <LatLng>[];
    for (final leg in itinerary.legs) {
      final geometry = leg.legGeometry;
      if (geometry != null && geometry.points.isNotEmpty) {
        try {
          points.addAll(_decodePolyline(geometry.points, geometry.precision));
          continue;
        } catch (_) {}
      }
      if (leg.fromLat != 0.0 || leg.fromLon != 0.0) {
        points.add(LatLng(leg.fromLat, leg.fromLon));
      }
      if (leg.toLat != 0.0 || leg.toLon != 0.0) {
        points.add(LatLng(leg.toLat, leg.toLon));
      }
    }
    if (points.isEmpty) return;
    final first = points.first;
    double minLat = first.latitude;
    double maxLat = first.latitude;
    double minLon = first.longitude;
    double maxLon = first.longitude;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }
    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);
    if (points.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(center, _focusedTransferZoomLevel),
      );
      return;
    }

    final approxDistance = coordinateDistanceInMeters(
      points.first.latitude,
      points.first.longitude,
      points.last.latitude,
      points.last.longitude,
    );
    if (approxDistance <= _focusedTransferDistanceThresholdMeters) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(center, _focusedTransferZoomLevel),
      );
      return;
    }

    final bounds = LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 48,
          top: 64,
          right: 48,
          bottom: 220,
        ),
      );
    } catch (_) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(center, _focusedTransferZoomLevel),
      );
    }
  }

  Future<void> _clearFocusedRoute() async {
    final controller = _controller;
    if (controller == null || !_didAddFocusedRouteLayer) return;
    try {
      await controller.setGeoJsonSource(
        _kFocusedRouteSourceId,
        _emptyFeatureCollection(),
      );
    } catch (_) {}
  }

  Future<void> _clearFocusedVehicles() async {
    final controller = _controller;
    if (controller == null) return;
    _focusedVehicles.clear();
    if (!_didAddFocusedVehiclesLayer) return;
    try {
      await controller.setGeoJsonSource(
        _kFocusedVehiclesSourceId,
        _emptyFeatureCollection(),
      );
    } catch (_) {}
  }

  Future<void> _clearFocusedStops() async {
    final controller = _controller;
    if (controller == null) return;
    _focusedStops.clear();
    if (!_didAddFocusedStopsLayer) return;
    try {
      await controller.setGeoJsonSource(
        _kFocusedStopsSourceId,
        _emptyFeatureCollection(),
      );
    } catch (_) {}
  }

  Future<void> _pushVehicleSource(DateTime now) async {
    final controller = _controller;
    if (controller == null || !_didAddVehiclesLayer || _isTripFocus) return;
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
    if (layerId == _kVehiclesLayerId || layerId == _kFocusedVehiclesLayerId) {
      if (_isTripFocus) return;
      Haptics.lightTick();
      _enterTripFocus(id);
      return;
    }
    if (layerId != _kStopsLayerId) return;
    if (!_isSheetCollapsed) return;
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

  void _enterTripFocus(String tripId) {
    if (tripId.isEmpty) return;
    _showStopsBeforeFocus = _showStops;
    _animateCollapsedHeightChange(_tripFocusBottomBarHeight);
    setState(() {
      _isTripFocus = true;
      _isQuickSettings = false;
      _isTripFocusLoading = true;
      _tripFocusError = null;
      _focusedTripId = tripId;
      _focusedItinerary = null;
      _focusedStopsColor = null;
      _showStops = false;
    });
    _unfocusInputs();
    _clearSuggestions();
    _closeTimeSelectionOverlay();
    _dismissStopOverlay(animated: false);
    _dismissLongPressOverlay(animated: false);
    unawaited(_removeRouteSymbols());
    _applyStopsLayerVisibility();
    _applyVehiclesLayerVisibility();
    _applyFocusedVehiclesLayerVisibility();
    _applyFocusedStopsLayerVisibility();
    _applyFocusedRouteVisibility();
    unawaited(_clearFocusedRoute());
    unawaited(_clearFocusedVehicles());
    unawaited(_clearFocusedStops());
    _focusedRouteKeys.clear();
    _focusedRouteColors.clear();
    _focusedTripIds.clear();
    _lastTripsRequestKey = null;
    _lastStopsRequestKey = null;
    unawaited(_loadFocusedTripDetails(tripId));
    unawaited(_refreshFocusedTripVehicles(force: true));
  }

  void _exitTripFocus() {
    _animateCollapsedHeightChange(_bottomBarHeight);
    setState(() {
      _isTripFocus = false;
      _isTripFocusLoading = false;
      _tripFocusError = null;
      _focusedTripId = null;
      _focusedItinerary = null;
      _focusedStopsColor = null;
      _showStops = _showStopsBeforeFocus;
    });
    _lastTripsRequestKey = null;
    _lastStopsRequestKey = null;
    unawaited(_clearFocusedRoute());
    unawaited(_clearFocusedVehicles());
    unawaited(_clearFocusedStops());
    _focusedRouteKeys.clear();
    _focusedRouteColors.clear();
    _focusedTripIds.clear();
    _applyStopsLayerVisibility();
    _applyVehiclesLayerVisibility();
    _applyFocusedVehiclesLayerVisibility();
    _applyFocusedStopsLayerVisibility();
    _applyFocusedRouteVisibility();
    unawaited(_refreshRouteMarkers(allowFit: false));
    _scheduleTripRefresh();
    _scheduleStopRefresh();
  }

  void _openQuickSettings() {
    if (_isQuickSettings) return;
    _unfocusInputs();
    _clearSuggestions();
    _closeTimeSelectionOverlay();
    _dismissStopOverlay(animated: false);
    _dismissLongPressOverlay(animated: false);
    setState(() => _isQuickSettings = true);
    final expandedTop = _lastComputedExpandedTop;
    final collapsedTop = _lastComputedCollapsedTop;
    if (expandedTop != null && collapsedTop != null) {
      _animateTo(expandedTop, collapsedTop);
      _stopDragRumble();
    }
  }

  void _closeQuickSettings() {
    if (!_isQuickSettings) return;
    _animateCollapsedHeightChange(_bottomBarHeight);
    setState(() => _isQuickSettings = false);
  }

  Future<void> _loadFocusedTripDetails(String tripId) async {
    final requestId = ++_focusedTripRequestId;
    try {
      final itinerary = await TripDetailsService.fetchTripDetails(
        tripId: tripId,
      );
      if (!mounted || requestId != _focusedTripRequestId) return;
      setState(() {
        _focusedItinerary = itinerary;
        _isTripFocusLoading = false;
      });
      _focusedStopsColor = _focusedRouteColor(itinerary);
      _focusedRouteKeys
        ..clear()
        ..addAll(_buildFocusedRouteKeys(itinerary));
      _focusedRouteColors
        ..clear()
        ..addAll(_buildFocusedRouteColors(itinerary));
      _focusedTripIds
        ..clear()
        ..addAll(_buildFocusedTripIds(itinerary));
      unawaited(_setFocusedRoute(itinerary));
      unawaited(_setFocusedStops(itinerary));
      unawaited(_refreshFocusedTripVehicles(force: true));
      _applyFocusedStopsLayerVisibility();
      _applyFocusedRouteVisibility();
      unawaited(_fitCameraToFocusedItinerary(itinerary));
    } catch (e) {
      if (!mounted || requestId != _focusedTripRequestId) return;
      setState(() {
        _focusedItinerary = null;
        _isTripFocusLoading = false;
        _tripFocusError = 'Failed to load trip.';
      });
    }
  }

  Future<void> _pushFocusedVehicleSource(DateTime now) async {
    final controller = _controller;
    if (controller == null || !_didAddFocusedVehiclesLayer) return;
    if (_focusedVehicles.isEmpty) {
      try {
        await controller.setGeoJsonSource(
          _kFocusedVehiclesSourceId,
          _emptyFeatureCollection(),
        );
      } catch (_) {}
      return;
    }

    final features = <Map<String, dynamic>>[];
    for (final entry in _focusedVehicles.entries) {
      final marker = entry.value;
      final position =
          marker.lastPosition ??
          _positionAlongSegment(marker.segmentData, now);
      features.add(_vehicleFeature(entry.key, marker, position));
    }
    try {
      await controller.setGeoJsonSource(
        _kFocusedVehiclesSourceId,
        {'type': 'FeatureCollection', 'features': features},
      );
    } catch (_) {}
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

  void _onStopTimeSelected(StopTime stopTime) {
    if (stopTime.tripId.isEmpty) return;
    Haptics.lightTick();
    _enterTripFocus(stopTime.tripId);
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

  void _openAllSettings() {
    if (_isQuickSettings) {
      _closeQuickSettings();
    }
    widget.onTabChangeRequested?.call(2);
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
        n: 3,
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

enum _QuickButtonAction {
  toggleStops,
  toggleVehicles,
  toggleRealtimeOnly,
  changeMapStyle,
}

enum _VehicleModeGroup { train, metro, tram, bus, ferry, lift, other }

class _QuickButtonOption {
  const _QuickButtonOption({
    required this.action,
    required this.label,
    required this.icon,
    this.subtitle,
    this.enabled = true,
  });

  final _QuickButtonAction action;
  final String label;
  final IconData icon;
  final String? subtitle;
  final bool enabled;
}

class _QuickButtonConfig {
  const _QuickButtonConfig({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
}

class _MapControlPills extends StatelessWidget {
  const _MapControlPills({
    required this.quickButton,
    required this.onLocate,
    required this.onSettings,
  });

  final _QuickButtonConfig quickButton;
  final VoidCallback onLocate;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    final TextStyle quickLabelStyle = TextStyle(
      color: quickButton.color,
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
              onTap: quickButton.onTap,
              width: 116,
              leading: Icon(
                quickButton.icon,
                size: 16,
                color: quickButton.color,
              ),
              label: Text(
                quickButton.label,
                textAlign: TextAlign.center,
                style: quickLabelStyle,
              ),
            ),
            const SizedBox(width: 8),
            _MapControlChip(
              onTap: onLocate,
              width: 92,
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
            const SizedBox(width: 8),
            _MapControlIconChip(
              onTap: onSettings,
              icon: LucideIcons.settings2,
              size: 40,
            ),
          ],
        ),
      ),
    );
  }
}

class _TripFocusBottomCard extends StatelessWidget {
  const _TripFocusBottomCard({
    required this.onHandleTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onBack,
    required this.itinerary,
    required this.isLoading,
    required this.errorMessage,
    required this.bottomSpacer,
  });

  final VoidCallback onHandleTap;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;
  final VoidCallback onBack;
  final Itinerary? itinerary;
  final bool isLoading;
  final String? errorMessage;
  final double bottomSpacer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 14,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onHandleTap,
              onVerticalDragStart: (_) => onDragStart(),
              onVerticalDragUpdate: (d) => onDragUpdate(d.delta.dy),
              onVerticalDragEnd: (d) => onDragEnd(d.velocity.pixelsPerSecond.dy),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 18),
                  Container(
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PressableHighlight(
                  onPressed: onBack,
                  borderRadius: BorderRadius.circular(14),
                  highlightColor: AppColors.accentOf(context),
                  enableHaptics: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.chevronLeft,
                        size: 18,
                        color: AppColors.accentOf(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _TripFocusContent(
                itinerary: itinerary,
                isLoading: isLoading,
                errorMessage: errorMessage,
                bottomSpacer: bottomSpacer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSettingsBottomCard extends StatelessWidget {
  const _QuickSettingsBottomCard({
    required this.onHandleTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onBack,
    required this.bottomSpacer,
    required this.quickButtonAction,
    required this.quickButtonOptions,
    required this.showVehicles,
    required this.hideNonRealtime,
    required this.showStops,
    required this.vehicleModeVisibility,
    required this.onQuickButtonChanged,
    required this.onShowVehiclesChanged,
    required this.onHideNonRealtimeChanged,
    required this.onVehicleModeChanged,
    required this.onShowStopsChanged,
    required this.onOpenAllSettings,
  });

  final VoidCallback onHandleTap;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;
  final VoidCallback onBack;
  final double bottomSpacer;
  final _QuickButtonAction quickButtonAction;
  final List<_QuickButtonOption> quickButtonOptions;
  final bool showVehicles;
  final bool hideNonRealtime;
  final bool showStops;
  final Map<_VehicleModeGroup, bool> vehicleModeVisibility;
  final ValueChanged<_QuickButtonAction> onQuickButtonChanged;
  final ValueChanged<bool> onShowVehiclesChanged;
  final ValueChanged<bool> onHideNonRealtimeChanged;
  final void Function(_VehicleModeGroup, bool) onVehicleModeChanged;
  final ValueChanged<bool> onShowStopsChanged;
  final VoidCallback onOpenAllSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 14,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onHandleTap,
              onVerticalDragStart: (_) => onDragStart(),
              onVerticalDragUpdate: (d) => onDragUpdate(d.delta.dy),
              onVerticalDragEnd: (d) => onDragEnd(d.velocity.pixelsPerSecond.dy),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 18),
                  Container(
                    width: 48,
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppColors.black.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: PressableHighlight(
                  onPressed: onBack,
                  borderRadius: BorderRadius.circular(14),
                  highlightColor: AppColors.accentOf(context),
                  enableHaptics: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.chevronLeft,
                        size: 18,
                        color: AppColors.accentOf(context),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Back',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.accentOf(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: _QuickSettingsContent(
                quickButtonAction: quickButtonAction,
                quickButtonOptions: quickButtonOptions,
                showVehicles: showVehicles,
                hideNonRealtime: hideNonRealtime,
                showStops: showStops,
                vehicleModeVisibility: vehicleModeVisibility,
                onQuickButtonChanged: onQuickButtonChanged,
                onShowVehiclesChanged: onShowVehiclesChanged,
                onHideNonRealtimeChanged: onHideNonRealtimeChanged,
                onVehicleModeChanged: onVehicleModeChanged,
                onShowStopsChanged: onShowStopsChanged,
                onOpenAllSettings: onOpenAllSettings,
                bottomSpacer: bottomSpacer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TripFocusContent extends StatelessWidget {
  const _TripFocusContent({
    required this.itinerary,
    required this.isLoading,
    required this.errorMessage,
    required this.bottomSpacer,
  });

  final Itinerary? itinerary;
  final bool isLoading;
  final String? errorMessage;
  final double bottomSpacer;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Shimmer.fromColors(
        baseColor: const Color(0x1A000000),
        highlightColor: const Color(0x0D000000),
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  height: 140,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Container(
                  height: 420,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              SizedBox(height: bottomSpacer),
            ],
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            errorMessage!,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.black.withValues(alpha: 0.55),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final itinerary = this.itinerary;
    if (itinerary == null || itinerary.legs.isEmpty) {
      return Center(
        child: Text(
          'No trip data available',
          style: TextStyle(
            fontSize: 15,
            color: AppColors.black.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    final focusLeg = itinerary.legs.firstWhere(
      (leg) => leg.mode != 'WALK',
      orElse: () => itinerary.legs.first,
    );
    final routeColor =
        parseHexColor(focusLeg.routeColor) ?? AppColors.accentOf(context);
    final routeTextColor =
        parseHexColor(focusLeg.routeTextColor) ?? AppColors.solidWhite;
    final modeIcon = getLegIcon(focusLeg.mode);
    final headerText =
        focusLeg.displayName?.trim().isNotEmpty == true
            ? focusLeg.displayName!
            : focusLeg.routeShortName?.trim().isNotEmpty == true
            ? focusLeg.routeShortName!
            : getTransitModeName(focusLeg.mode);
    final headsign =
        focusLeg.headsign?.trim().isNotEmpty == true
            ? focusLeg.headsign
            : null;
    final stops = _buildJourneyStops(focusLeg);
    final (vehicleStopIndex, isVehicleAtStation, isBeforeStart, isAfterEnd) =
        _estimateVehiclePosition(stops);
    final showVehicle =
        vehicleStopIndex >= 0 && vehicleStopIndex < stops.length;
    final timelineItems = <_TimelineItem>[];
    for (int i = 0; i < stops.length; i++) {
      timelineItems.add(_TimelineItem(stop: stops[i], isVehicle: false));
      if (showVehicle &&
          !isVehicleAtStation &&
          i == vehicleStopIndex &&
          i < stops.length - 1) {
        timelineItems.add(_TimelineItem(stop: null, isVehicle: true));
      }
    }

    int upcomingStopIndex = -1;
    if (showVehicle) {
      if (isVehicleAtStation) {
        upcomingStopIndex = vehicleStopIndex < stops.length - 1
            ? vehicleStopIndex + 1
            : -1;
      } else {
        upcomingStopIndex = vehicleStopIndex < stops.length - 1
            ? vehicleStopIndex + 1
            : -1;
      }
    }
    final currentStopIndex = isBeforeStart
        ? -1
        : isAfterEnd
        ? (stops.isEmpty ? -1 : stops.length - 1)
        : vehicleStopIndex;
    final allAlerts = <String, Alert>{};
    for (final stop in stops) {
      for (final alert in stop.alerts) {
        if (alert.headerText != null || alert.descriptionText != null) {
          final key = '${alert.headerText}|${alert.descriptionText}';
          allAlerts[key] = alert;
        }
      }
    }
    for (final alert in focusLeg.alerts) {
      if (alert.headerText != null || alert.descriptionText != null) {
        final key = '${alert.headerText}|${alert.descriptionText}';
        allAlerts[key] = alert;
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      modeIcon,
                      size: 32,
                      color: AppColors.black,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (headerText.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: routeColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                headerText,
                                style: TextStyle(
                                  color: routeTextColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (headsign != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${getTransitModeName(focusLeg.mode)} • $headsign',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: AppColors.black,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (allAlerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Warnings',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ...allAlerts.values.map((alert) {
                    final hasTitle =
                        alert.headerText != null &&
                        alert.headerText!.isNotEmpty;
                    final hasBody =
                        alert.descriptionText != null &&
                        alert.descriptionText!.isNotEmpty;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF3CD),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFC107)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              LucideIcons.triangleAlert,
                              size: 16,
                              color: Color(0xFFF57C00),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (hasTitle)
                                    Text(
                                      alert.headerText!,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.black,
                                      ),
                                    ),
                                  if (hasBody) ...[
                                    if (hasTitle) const SizedBox(height: 2),
                                    Text(
                                      alert.descriptionText!,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.black.withValues(
                                          alpha: 0.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (focusLeg.realTime)
                      const InfoChip(
                        icon: LucideIcons.radio,
                        label: 'Real-time',
                      ),
                    if (focusLeg.cancelled == true)
                      const InfoChip(
                        icon: LucideIcons.x,
                        label: 'CANCELLED',
                        tint: Color(0xFFD32F2F),
                      ),
                    InfoChip(
                      icon: LucideIcons.clock,
                      label: formatDuration(focusLeg.duration),
                    ),
                    if (focusLeg.distance != null)
                      InfoChip(
                        icon: LucideIcons.ruler,
                        label:
                            '${(focusLeg.distance! / 1000).toStringAsFixed(1)} km',
                      ),
                    if (focusLeg.agencyName != null)
                      InfoChip(
                        icon: LucideIcons.building,
                        label: focusLeg.agencyName!,
                      ),
                    if (focusLeg.routeLongName != null &&
                        focusLeg.routeLongName!.isNotEmpty)
                      InfoChip(
                        icon: LucideIcons.route,
                        label: focusLeg.routeLongName!,
                      ),
                    if (itinerary.fare != null)
                      InfoChip(
                        icon: LucideIcons.coins,
                        label:
                            '${itinerary.fare!.amount.toStringAsFixed(2)} ${itinerary.fare!.currency}',
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Journey',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 16),
                if (stops.isEmpty)
                  Text(
                    'No stops available',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.black.withValues(alpha: 0.6),
                    ),
                  )
                else
                  FixedTimeline.tileBuilder(
                    theme: TimelineThemeData(
                      nodePosition: 0.08,
                      color: routeColor,
                      indicatorTheme: const IndicatorThemeData(size: 28),
                      connectorTheme: const ConnectorThemeData(thickness: 2.5),
                    ),
                    builder: TimelineTileBuilder.connected(
                      itemCount: timelineItems.length,
                      connectionDirection: ConnectionDirection.before,
                      contentsBuilder: (context, index) {
                        final item = timelineItems[index];
                        if (item.isVehicle && item.stop == null) {
                          return const SizedBox.shrink();
                        }

                        final stop = item.stop!;
                        final stopIndex = stops.indexOf(stop);
                        final isPassed = stopIndex <= currentStopIndex;
                        final isUpcoming = stopIndex == upcomingStopIndex;

                        final arrRow = _buildStopScheduleRow(
                          'Arr',
                          stop.scheduledArrival,
                          stop.arrival,
                          isPassed,
                        );
                        final depRow = _buildStopScheduleRow(
                          'Dep',
                          stop.scheduledDeparture,
                          stop.departure,
                          isPassed,
                        );

                        return Padding(
                          padding: const EdgeInsets.only(left: 12, bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      stop.name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight:
                                            stopIndex == 0 ||
                                                stopIndex ==
                                                    stops.length - 1 ||
                                                isUpcoming
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isPassed
                                            ? AppColors.black.withValues(
                                                alpha: 0.5,
                                              )
                                            : AppColors.black,
                                      ),
                                    ),
                                  ),
                                  if (isUpcoming) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: routeColor.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Upcoming',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: routeColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              if (arrRow != null || depRow != null) ...[
                                const SizedBox(height: 2),
                                if (arrRow != null) arrRow,
                                if (depRow != null) ...[
                                  if (arrRow != null)
                                    const SizedBox(height: 2),
                                  depRow,
                                ],
                              ],
                              if (stop.track != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  'Track ${stop.track}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isPassed
                                        ? AppColors.black.withValues(
                                            alpha: 0.4,
                                          )
                                        : AppColors.black.withValues(
                                            alpha: 0.5,
                                          ),
                                  ),
                                ),
                              ],
                              if (stop.cancelled == true) ...[
                                const SizedBox(height: 2),
                                const Text(
                                  'CANCELLED',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFD32F2F),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                      indicatorBuilder: (context, index) {
                        final item = timelineItems[index];
                        if (item.isVehicle && item.stop == null) {
                          return _IndicatorBox(
                            lineColor: routeColor,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: routeColor,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Icon(
                                  modeIcon,
                                  size: 14,
                                  color: routeTextColor,
                                ),
                              ),
                            ),
                          );
                        }

                        final stop = item.stop!;
                        final stopIndex = stops.indexOf(stop);
                        final isPassed = stopIndex <= currentStopIndex;
                        final bool isTerminal =
                            stopIndex == 0 || stopIndex == stops.length - 1;
                        final double dotSize = isTerminal ? 16 : 12;
                        final Color dotColor = isPassed
                            ? routeColor.withValues(alpha: 0.6)
                            : routeColor;
                        final bool isVehicleHere =
                            showVehicle &&
                            isVehicleAtStation &&
                            stopIndex == vehicleStopIndex;
                        final bool isFirstStop = stopIndex == 0;
                        final bool isLastStop = stopIndex == stops.length - 1;

                        if (isVehicleHere) {
                          return _IndicatorBox(
                            lineColor: dotColor,
                            centerGap: 28.0,
                            cutTop: isFirstStop,
                            cutBottom: isLastStop,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                DotIndicator(color: dotColor, size: dotSize),
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: routeColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    modeIcon,
                                    size: 14,
                                    color: routeTextColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        return _IndicatorBox(
                          lineColor: dotColor,
                          centerGap: dotSize,
                          cutTop: isFirstStop,
                          cutBottom: isLastStop,
                          child: Center(
                            child: DotIndicator(color: dotColor, size: dotSize),
                          ),
                        );
                      },
                      connectorBuilder: (context, index, connectorType) {
                        bool isPassed = false;
                        if (index < timelineItems.length) {
                          final item = timelineItems[index];
                          if (item.isVehicle) {
                            isPassed = true;
                          } else {
                            final stopIndex = stops.indexOf(item.stop!);
                            isPassed = stopIndex <= currentStopIndex;
                          }
                        }

                        return SolidLineConnector(
                          color: isPassed
                              ? routeColor.withValues(alpha: 0.6)
                              : routeColor,
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 100),
        ],
      ),
    );
  }

  bool _isSameMinute(DateTime a, DateTime b) {
    final aLocal = a.toLocal();
    final bLocal = b.toLocal();
    return aLocal.year == bLocal.year &&
        aLocal.month == bLocal.month &&
        aLocal.day == bLocal.day &&
        aLocal.hour == bLocal.hour &&
        aLocal.minute == bLocal.minute;
  }

  (int, bool, bool, bool) _estimateVehiclePosition(
    List<_JourneyStop> stops,
  ) {
    if (stops.isEmpty) return (-1, false, false, false);
    final now = DateTime.now();

    final firstStop = stops.first;
    final firstDeparture = firstStop.departure ?? firstStop.arrival;
    if (firstDeparture != null &&
        !_isSameMinute(now, firstDeparture) &&
        now.isBefore(firstDeparture)) {
      return (0, true, true, false);
    }

    final lastStop = stops.last;
    final lastArrival = lastStop.arrival ?? lastStop.departure;
    if (lastArrival != null &&
        !_isSameMinute(now, lastArrival) &&
        now.isAfter(lastArrival)) {
      return (stops.length - 1, true, false, true);
    }

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final arrival = stop.arrival;
      final departure = stop.departure;

      if (departure != null && _isSameMinute(now, departure)) {
        return (i, true, false, false);
      }

      if (arrival != null && departure != null) {
        if (now.isAfter(arrival) && now.isBefore(departure)) {
          return (i, true, false, false);
        }
      }

      final nextTime = departure ?? arrival;
      if (nextTime != null &&
          now.isBefore(nextTime) &&
          !_isSameMinute(now, nextTime)) {
        return (i - 1, false, false, false);
      }
    }

    return (stops.length - 1, true, false, true);
  }

  List<_JourneyStop> _buildJourneyStops(Leg leg) {
    final stops = <_JourneyStop>[];

    stops.add(
      _JourneyStop(
        name: leg.fromName,
        lat: leg.fromLat,
        lon: leg.fromLon,
        arrival: null,
        departure: leg.startTime,
        scheduledArrival: null,
        scheduledDeparture: leg.scheduledStartTime,
        track: leg.fromTrack,
        scheduledTrack: leg.fromScheduledTrack,
        cancelled: leg.cancelled,
        alerts: const [],
      ),
    );

    for (final stop in leg.intermediateStops) {
      stops.add(
        _JourneyStop(
          name: stop.name,
          lat: stop.lat,
          lon: stop.lon,
          arrival: stop.arrival,
          departure: stop.departure,
          scheduledArrival: stop.scheduledArrival,
          scheduledDeparture: stop.scheduledDeparture,
          track: stop.track,
          scheduledTrack: stop.scheduledTrack,
          cancelled: stop.cancelled,
          alerts: stop.alerts,
        ),
      );
    }

    stops.add(
      _JourneyStop(
        name: leg.toName,
        lat: leg.toLat,
        lon: leg.toLon,
        arrival: leg.endTime,
        departure: null,
        scheduledArrival: leg.scheduledEndTime,
        scheduledDeparture: null,
        track: leg.toTrack,
        scheduledTrack: leg.toScheduledTrack,
        cancelled: leg.cancelled,
        alerts: const [],
      ),
    );

    return stops;
  }

  Widget? _buildStopScheduleRow(
    String label,
    DateTime? scheduled,
    DateTime? actual,
    bool isPassed,
  ) {
    if (scheduled == null && actual == null) return null;
    final display = formatTime(scheduled ?? actual);
    final delay = (scheduled != null && actual != null)
        ? computeDelay(scheduled, actual)
        : null;
    final baseColor = isPassed
        ? AppColors.black.withValues(alpha: 0.4)
        : AppColors.black.withValues(alpha: 0.6);
    return Row(
      children: [
        Text(
          '$label $display',
          style: TextStyle(fontSize: 13, color: baseColor),
        ),
        if (delay != null) ...[
          const SizedBox(width: 6),
          Text(
            formatDelay(delay),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _delayColor(delay),
            ),
          ),
        ],
      ],
    );
  }

  Color _delayColor(Duration delay) =>
      delay.isNegative ? const Color(0xFF2E7D32) : const Color(0xFFB26A00);
}

class _QuickSettingsContent extends StatelessWidget {
  const _QuickSettingsContent({
    required this.quickButtonAction,
    required this.quickButtonOptions,
    required this.showVehicles,
    required this.hideNonRealtime,
    required this.showStops,
    required this.vehicleModeVisibility,
    required this.onQuickButtonChanged,
    required this.onShowVehiclesChanged,
    required this.onHideNonRealtimeChanged,
    required this.onVehicleModeChanged,
    required this.onShowStopsChanged,
    required this.onOpenAllSettings,
    required this.bottomSpacer,
  });

  final _QuickButtonAction quickButtonAction;
  final List<_QuickButtonOption> quickButtonOptions;
  final bool showVehicles;
  final bool hideNonRealtime;
  final bool showStops;
  final Map<_VehicleModeGroup, bool> vehicleModeVisibility;
  final ValueChanged<_QuickButtonAction> onQuickButtonChanged;
  final ValueChanged<bool> onShowVehiclesChanged;
  final ValueChanged<bool> onHideNonRealtimeChanged;
  final void Function(_VehicleModeGroup, bool) onVehicleModeChanged;
  final ValueChanged<bool> onShowStopsChanged;
  final VoidCallback onOpenAllSettings;
  final double bottomSpacer;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    Text sectionTitle(String title) {
      return Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          color: AppColors.black.withValues(alpha: 0.5),
        ),
      );
    }

    Widget sectionCard({
      required String title,
      required Widget child,
    }) {
      return CustomCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle(title),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionCard(
            title: 'Quick button',
            child: _QuickButtonSelectField(
              value: quickButtonAction,
              options: quickButtonOptions,
              onChanged: onQuickButtonChanged,
            ),
          ),
          sectionCard(
            title: 'Map layers',
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final width = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: width,
                      child: _QuickModeCard(
                        label: 'Vehicles',
                        icon: LucideIcons.busFront,
                        selected: showVehicles,
                        onTap: () => onShowVehiclesChanged(!showVehicles),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _QuickModeCard(
                        label: 'Stops',
                        icon: LucideIcons.mapPin,
                        selected: showStops,
                        onTap: () => onShowStopsChanged(!showStops),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1.0,
                  child: child,
                ),
              );
            },
            child: showVehicles
                ? Column(
                    key: const ValueKey('quick-settings-vehicles'),
                    children: [
                      sectionCard(
                        title: 'Live data',
                        child: _QuickToggleRow(
                          label: 'Show only real-time data',
                          value: hideNonRealtime,
                          onChanged: onHideNonRealtimeChanged,
                        ),
                      ),
                      sectionCard(
                        title: 'Vehicle types',
                        child: _VehicleModesGrid(
                          visibility: vehicleModeVisibility,
                          onChanged: onVehicleModeChanged,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(
                    key: ValueKey('quick-settings-vehicles-empty'),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Align(
              alignment: Alignment.center,
              child: PressableHighlight(
                onPressed: onOpenAllSettings,
                highlightColor: accent,
                borderRadius: BorderRadius.circular(14),
                enableHaptics: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.settings,
                      size: 18,
                      color: accent,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'All settings',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: bottomSpacer),
        ],
      ),
    );
  }
}

class _QuickButtonSelectField extends StatefulWidget {
  const _QuickButtonSelectField({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final _QuickButtonAction value;
  final List<_QuickButtonOption> options;
  final ValueChanged<_QuickButtonAction> onChanged;

  @override
  State<_QuickButtonSelectField> createState() =>
      _QuickButtonSelectFieldState();
}

class _QuickButtonSelectFieldState extends State<_QuickButtonSelectField> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  void _openPicker() {
    final pickerOptions = widget.options
        .map(
          (option) => QuickButtonPickerOption<_QuickButtonAction>(
            value: option.action,
            label: option.label,
            icon: option.icon,
            subtitle: option.subtitle,
            enabled: option.enabled,
          ),
        )
        .toList();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Quick button',
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) {
        return QuickButtonPickerSheet<_QuickButtonAction>(
          selected: widget.value,
          options: pickerOptions,
          onSelected: (action) {
            widget.onChanged(action);
          },
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.black.withValues(alpha: 0.12);
    final baseFill = AppColors.black.withValues(alpha: 0.03);
    final pressedFill = AppColors.black.withValues(alpha: 0.06);
    final selected = widget.options.firstWhere(
      (option) => option.action == widget.value,
      orElse: () => widget.options.first,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openPicker,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed ? pressedFill : baseFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(
              selected.icon,
              size: 16,
              color: AppColors.black,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: AppColors.black.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickModeCard extends StatelessWidget {
  const _QuickModeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : const Color(0x14000000),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? accent : AppColors.black,
                ),
              ),
            ),
            Icon(
              selected ? LucideIcons.check : LucideIcons.plus,
              size: 16,
              color: selected ? accent : const Color(0x33000000),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickToggleRow extends StatelessWidget {
  const _QuickToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final labelColor =
        value ? AppColors.black : AppColors.black.withValues(alpha: 0.6);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
            _MiniSwitch(value: value),
          ],
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final trackColor = value
        ? accent
        : AppColors.black.withValues(alpha: 0.14);
    final borderColor = value
        ? accent.withValues(alpha: 0.7)
        : AppColors.black.withValues(alpha: 0.14);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 30,
      height: 16,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.16),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleModesGrid extends StatelessWidget {
  const _VehicleModesGrid({
    required this.visibility,
    required this.onChanged,
  });

  final Map<_VehicleModeGroup, bool> visibility;
  final void Function(_VehicleModeGroup, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    const entries = <_VehicleModeGroup, String>{
      _VehicleModeGroup.train: 'Trains',
      _VehicleModeGroup.metro: 'Metro',
      _VehicleModeGroup.tram: 'Tram',
      _VehicleModeGroup.bus: 'Bus',
      _VehicleModeGroup.ferry: 'Ferries',
      _VehicleModeGroup.lift: 'Lifts',
      _VehicleModeGroup.other: 'Other',
    };

    IconData iconFor(_VehicleModeGroup mode) {
      switch (mode) {
        case _VehicleModeGroup.train:
          return LucideIcons.trainFront;
        case _VehicleModeGroup.metro:
          return LucideIcons.squareArrowDown;
        case _VehicleModeGroup.tram:
          return LucideIcons.tramFront;
        case _VehicleModeGroup.bus:
          return LucideIcons.busFront;
        case _VehicleModeGroup.ferry:
          return LucideIcons.ship;
        case _VehicleModeGroup.lift:
          return LucideIcons.cableCar;
        case _VehicleModeGroup.other:
          return LucideIcons.sparkles;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing) / 2;
        final totalWidth = constraints.maxWidth;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final entry in entries.entries)
              SizedBox(
                width: entry.key == _VehicleModeGroup.other
                    ? totalWidth
                    : width,
                child: _QuickModeCard(
                  label: entry.value,
                  icon: iconFor(entry.key),
                  selected: visibility[entry.key] ?? true,
                  onTap: () {
                    final current = visibility[entry.key] ?? true;
                    onChanged(entry.key, !current);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}

class _JourneyStop {
  const _JourneyStop({
    required this.name,
    required this.lat,
    required this.lon,
    required this.arrival,
    required this.departure,
    required this.scheduledArrival,
    required this.scheduledDeparture,
    required this.track,
    required this.scheduledTrack,
    required this.cancelled,
    required this.alerts,
  });

  final String name;
  final double lat;
  final double lon;
  final DateTime? arrival;
  final DateTime? departure;
  final DateTime? scheduledArrival;
  final DateTime? scheduledDeparture;
  final String? track;
  final String? scheduledTrack;
  final bool cancelled;
  final List<Alert> alerts;
}

class _TimelineItem {
  final _JourneyStop? stop;
  final bool isVehicle;

  _TimelineItem({this.stop, required this.isVehicle});
}

class _IndicatorBox extends StatelessWidget {
  const _IndicatorBox({
    required this.child,
    required this.lineColor,
    this.centerGap = 0.0,
    this.cutTop = false,
    this.cutBottom = false,
  });

  final Widget child;
  final Color lineColor;
  final double centerGap;
  final bool cutTop;
  final bool cutBottom;

  @override
  Widget build(BuildContext context) {
    final double gap = centerGap.clamp(0.0, 28.0);
    final double sideLen = (28.0 - gap) / 2.0;

    return SizedBox(
      width: 28,
      height: 28,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (!cutTop && sideLen > 0)
            Positioned(
              top: 0,
              child: SizedBox(
                width: 2.5,
                height: sideLen,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: lineColor),
                ),
              ),
            ),
          if (!cutBottom && sideLen > 0)
            Positioned(
              bottom: 0,
              child: SizedBox(
                width: 2.5,
                height: sideLen,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: lineColor),
                ),
              ),
            ),
          child,
        ],
      ),
    );
  }
}

class _MapControlIconChip extends StatelessWidget {
  const _MapControlIconChip({
    required this.onTap,
    required this.icon,
    this.size = 40,
  });

  final VoidCallback onTap;
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final iconSize = 16.0;
    return PillButton(
      onTap: onTap,
      padding: EdgeInsets.all(9),
      restingColor: AppColors.white,
      pressedColor: AppColors.white.withValues(alpha: 0.92),
      borderRadius: BorderRadius.circular(size / 2),
      borderColor: AppColors.black.withValues(alpha: 0.1),
      child: SizedBox(
        width: iconSize,
        height: iconSize,
        child: Center(
          child: Icon(icon, size: iconSize, color: AppColors.black),
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
    required this.onStopTimeTap,
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
  final ValueChanged<StopTime> onStopTimeTap;
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
                  onStopTimeTap: widget.onStopTimeTap,
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
    required this.onStopTimeTap,
    required this.onViewTimetable,
    required this.onDismiss,
  });

  final MapStop stop;
  final List<StopTime> stopTimes;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback onSelectFrom;
  final VoidCallback onSelectTo;
  final ValueChanged<StopTime> onStopTimeTap;
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
              'Departures & arrivals',
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
              onStopTimeTap: onStopTimeTap,
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.center,
              child: PressableHighlight(
                onPressed: onViewTimetable,
                highlightColor: AppColors.accentOf(context),
                borderRadius: BorderRadius.circular(14),
                enableHaptics: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
    required this.onStopTimeTap,
  });

  final List<StopTime> stopTimes;
  final bool isLoading;
  final String? errorMessage;
  final ValueChanged<StopTime> onStopTimeTap;

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
          _StopTimePreviewRow(
            stopTime: stopTimes[i],
            onTap: () => onStopTimeTap(stopTimes[i]),
          ),
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
  const _StopTimePreviewRow({required this.stopTime, this.onTap});

  final StopTime stopTime;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final routeColor =
        parseHexColor(stopTime.routeColor) ?? AppColors.accentOf(context);
    final routeTextColor =
        parseHexColor(stopTime.routeTextColor) ?? AppColors.solidWhite;
    final arrival =
        formatTime(stopTime.place.arrival ?? stopTime.place.scheduledArrival);
    final departure =
        formatTime(stopTime.place.departure ?? stopTime.place.scheduledDeparture);
    final label = stopTime.displayName.isNotEmpty
        ? stopTime.displayName
        : stopTime.routeShortName;

    final content = Row(
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
    if (onTap == null) return content;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: content,
    );
  }
}
