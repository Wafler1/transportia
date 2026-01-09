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
import '../models/saved_place.dart';
import '../models/stop_time.dart';
import '../models/time_selection.dart';
import '../models/trip_history_item.dart';
import '../screens/itinerary_list_screen.dart';
import '../screens/location_settings_screen.dart';
import '../screens/timetables_screen.dart';
import '../services/favorites_service.dart';
import '../services/location_service.dart';
import '../services/recent_trips_service.dart';
import '../services/saved_places_service.dart';
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
import '../widgets/error_notice.dart';
import '../widgets/info_chip.dart';
import '../widgets/pressable_highlight.dart';
import '../widgets/quick_button_picker_sheet.dart';
import '../widgets/route_bottom_card.dart';
import '../widgets/route_suggestions_overlay.dart';
import '../widgets/validation_toast.dart';

part 'map_screen/map_screen_models.dart';
part 'map_screen/map_screen_controls.dart';
part 'map_screen/map_screen_trip_focus.dart';
part 'map_screen/map_screen_quick_settings.dart';
part 'map_screen/map_screen_overlays.dart';

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
  List<SavedPlace> _savedPlaces = [];
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
    unawaited(_loadSavedPlaces());
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
    final prefs = SharedPreferencesAsync();
    final stored = await prefs.getBool(_kShowStopsPrefKey);
    if (stored == null || !mounted) return;
    _setShowStops(stored, persist: false);
  }

  Future<void> _persistShowStopsPreference(bool value) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_kShowStopsPrefKey, value);
  }

  Future<void> _loadQuickSettingsPreferences() async {
    final prefs = SharedPreferencesAsync();
    final quickButtonKey = await prefs.getString(_kQuickButtonPrefKey);
    final showVehicles = await prefs.getBool(_kShowVehiclesPrefKey);
    final hideNonRt = await prefs.getBool(_kHideNonRtPrefKey);
    final train = await prefs.getBool(_kShowTrainPrefKey);
    final metro = await prefs.getBool(_kShowMetroPrefKey);
    final tram = await prefs.getBool(_kShowTramPrefKey);
    final bus = await prefs.getBool(_kShowBusPrefKey);
    final ferry = await prefs.getBool(_kShowFerryPrefKey);
    final lift = await prefs.getBool(_kShowLiftPrefKey);
    final other = await prefs.getBool(_kShowOtherPrefKey);
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
    final prefs = SharedPreferencesAsync();
    await prefs.setString(_kQuickButtonPrefKey, _quickButtonActionKey(action));
  }

  Future<void> _persistShowVehiclesPreference(bool value) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_kShowVehiclesPrefKey, value);
  }

  Future<void> _persistHideNonRtPreference(bool value) async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_kHideNonRtPrefKey, value);
  }

  Future<void> _persistVehicleModePreference(
    _VehicleModeGroup mode,
    bool value,
  ) async {
    final prefs = SharedPreferencesAsync();
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
          (segmentDelta == existingDelta && arr.isBefore(existing.arrival))) {
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
    final durationMs =
        data.arrival.millisecondsSinceEpoch -
        data.departure.millisecondsSinceEpoch;
    if (durationMs <= 0) return data.points.first;
    final t =
        (now.millisecondsSinceEpoch - data.departure.millisecondsSinceEpoch) /
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
        return FadeTransition(opacity: animation, child: child);
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
          final double bottomBarHeight = _isTripFocus
              ? _tripFocusBottomBarHeight
              : _bottomBarHeight;
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
          final showStopOverlay =
              _selectedStop != null || _isStopOverlayClosing;
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
                                    savedPlaces: _savedPlaces,
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
      if (_activeSuggestionField == kind) {
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
          final orderedResults = _prioritizeSavedSuggestions(results);
          setState(() {
            _suggestions = orderedResults;
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

  List<TransitousLocationSuggestion> _prioritizeSavedSuggestions(
    List<TransitousLocationSuggestion> results,
  ) {
    if (_savedPlaces.isEmpty) return results;
    final importanceByKey = <String, int>{
      for (final place in _savedPlaces) place.key: place.importance,
    };
    final indexBySuggestion = <TransitousLocationSuggestion, int>{};
    for (int i = 0; i < results.length; i++) {
      indexBySuggestion[results[i]] = i;
    }
    final ordered = List<TransitousLocationSuggestion>.from(results);
    ordered.sort((a, b) {
      final aKey = SavedPlace.buildKey(type: a.type, lat: a.lat, lon: a.lon);
      final bKey = SavedPlace.buildKey(type: b.type, lat: b.lat, lon: b.lon);
      final aImportance = importanceByKey[aKey];
      final bImportance = importanceByKey[bKey];
      final aSaved = aImportance != null;
      final bSaved = bImportance != null;
      if (aSaved != bSaved) {
        return aSaved ? -1 : 1;
      }
      if (aImportance != null && bImportance != null) {
        final diff = bImportance.compareTo(aImportance);
        if (diff != 0) return diff;
      }
      return indexBySuggestion[a]!.compareTo(indexBySuggestion[b]!);
    });
    return ordered;
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
    unawaited(_recordSavedPlace(suggestion));
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
  static const String _kFocusedVehiclesSourceId = 'map-focused-vehicles-source';
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

    final outerPaint = Paint()..color = AppColors.black.withValues(alpha: 0.2);
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
      'properties': {'id': tripId, 'iconId': marker.imageId},
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
      await controller.setGeoJsonSource(_kStopsSourceId, {
        'type': 'FeatureCollection',
        'features': features,
      });
    } catch (_) {}
  }

  Future<void> _setFocusedStopsSource(List<MapStop> stops) async {
    final controller = _controller;
    if (controller == null || !_didAddFocusedStopsLayer) return;
    final color =
        _focusedStopsColor ?? _stopAccentColor ?? AppColors.accentOf(context);
    final desiredId = _stopMarkerImageIdForColor(color);
    final imageId = _stopMarkerImageId == desiredId
        ? _stopMarkerImageId
        : await _ensureStopMarkerImageForColor(color);
    if (imageId == null) return;
    final features = stops.map((stop) => _stopFeature(stop, imageId)).toList();
    try {
      await controller.setGeoJsonSource(_kFocusedStopsSourceId, {
        'type': 'FeatureCollection',
        'features': features,
      });
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
          parseHexColor(leg.routeColor?.trim()) ?? _currentAccentColor();
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
      await controller.setGeoJsonSource(_kFocusedRouteSourceId, {
        'type': 'FeatureCollection',
        'features': features,
      });
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
          marker.lastPosition ?? _positionAlongSegment(marker.segmentData, now);
      features.add(_vehicleFeature(entry.key, marker, position));
    }
    try {
      await controller.setGeoJsonSource(_kVehiclesSourceId, {
        'type': 'FeatureCollection',
        'features': features,
      });
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
          marker.lastPosition ?? _positionAlongSegment(marker.segmentData, now);
      features.add(_vehicleFeature(entry.key, marker, position));
    }
    try {
      await controller.setGeoJsonSource(_kFocusedVehiclesSourceId, {
        'type': 'FeatureCollection',
        'features': features,
      });
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
    unawaited(_recordSavedPlace(suggestion));
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
    unawaited(_recordSavedPlace(suggestion));
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
      final filtered =
          deduped.where((entry) => _stopTimeKey(entry) != null).where((entry) {
            final time = _stopTimeKey(entry)!;
            return time.isAfter(now.subtract(const Duration(minutes: 1)));
          }).toList()..sort((a, b) {
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
      final departure = stopTime.place.departure?.toIso8601String() ?? '';
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

  Future<void> _loadSavedPlaces() async {
    final places = await SavedPlacesService.loadPlaces();
    if (!mounted) return;
    setState(() {
      _savedPlaces = places;
    });
  }

  Future<void> _recordSavedPlace(
    TransitousLocationSuggestion suggestion,
  ) async {
    final name = suggestion.name.trim();
    if (name.isEmpty) return;
    final selected = SavedPlace(
      name: name,
      type: suggestion.type,
      lat: suggestion.lat,
      lon: suggestion.lon,
      importance: SavedPlace.defaultImportance,
      city: suggestion.defaultArea,
      countryCode: suggestion.country,
    );
    final updated = SavedPlacesService.applySelection(_savedPlaces, selected);
    if (!mounted) return;
    setState(() {
      _savedPlaces = updated;
    });
    unawaited(SavedPlacesService.savePlaces(updated));
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
