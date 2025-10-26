import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:vibration/vibration.dart';
import '../animations/curves.dart';
import '../models/route_field_kind.dart';
import '../services/location_service.dart';
import '../services/transitous_geocode_service.dart';
import '../widgets/glass_icon_button.dart';
import '../widgets/route_bottom_card.dart';
import '../widgets/route_suggestions_overlay.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, this.deferInit = false, this.activateOnShow});

  // If true, skip location permission/init until activated.
  final bool deferInit;
  // Optional external trigger to activate deferred init when revealed.
  final ValueListenable<bool>? activateOnShow;
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen>
    with SingleTickerProviderStateMixin {
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

  @override
  void initState() {
    super.initState();
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
        }
        if (_isSheetCollapsed) {
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _centerToUserKeepZoom(),
          );
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
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _fromCtrl.removeListener(_handleFromTextChanged);
    _toCtrl.removeListener(_handleToTextChanged);
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _fromFocus.dispose();
    _toFocus.dispose();
    _stopDragRumble();
    _activateListener?.call();
    _activateListener = null;
    super.dispose();
    _snapCtrl.dispose();
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
      final pos = await LocationService.currentPosition(
        accuracy: LocationAccuracy.best,
      );
      target = LatLng(pos.latitude, pos.longitude);
      unawaited(LocationService.saveLastLatLng(target));
    }
    _is3DMode = false;
    _lastCam = CameraPosition(
      target: target,
      zoom: 16.0,
      tilt: 0.0,
      bearing: 0.0,
    );
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
      await _controller?.animateCamera(
        CameraUpdate.newCameraPosition(_lastCam),
      );
      _is3DMode = true;
    } else {
      final double outZoom = cam.zoom > 14.0 ? 14.0 : cam.zoom;
      _lastCam = CameraPosition(
        target: target,
        zoom: outZoom,
        bearing: 0.0,
        tilt: 0.0,
      );
      await _controller?.animateCamera(
        CameraUpdate.newCameraPosition(_lastCam),
      );
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
    return PopScope(
      canPop: !_isSheetCollapsed,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final expTop = _lastComputedExpandedTop;
          final colTop = _lastComputedCollapsedTop;
          if (expTop != null && colTop != null) {
            _animateTo(expTop, colTop);
            _stopDragRumble();
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
          }

          final animDuration =
              Duration.zero; // we animate snaps via controller (smoother)

          final denom = (collapsedTop - expandedTop);
          final progress = denom <= 0.0
              ? 1.0
              : ((_sheetTop! - expandedTop) / denom).clamp(0.0, 1.0);

          final overlayWidth = math.max(0.0, constraints.maxWidth - 24);
          final showOverlay = _activeSuggestionField != null;
          return Stack(
            children: [
              // Map behind (isolated repaint)
              Positioned.fill(
                child: RepaintBoundary(
                  child: MapLibreMap(
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
                ),
              ),

              // If expanded, tapping map collapses the sheet (doesn't interfere when collapsed)
              if (!_isSheetCollapsed)
                Positioned.fill(
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTap: () {
                      _unfocusInputs();
                      _stopDragRumble();
                      _animateTo(collapsedTop, collapsedTop);
                    },
                  ),
                ),

              // Map controls (only when sheet is collapsed)
              if (_isSheetCollapsed)
                SafeArea(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          GlassIconButton(
                            icon: _is3DMode
                                ? LucideIcons.undoDot
                                : LucideIcons.box,
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
                                  key: ValueKey(_activeSuggestionField),
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
    if (kind == RouteFieldKind.from) {
      if (_fromSelection == value) return;
      _fromSelection = value;
    } else {
      if (_toSelection == value) return;
      _toSelection = value;
    }
    if (notify && mounted) setState(() {});
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
  }

  void _onSuggestionSelected(
    RouteFieldKind field,
    TransitousLocationSuggestion suggestion,
  ) {
    _setControllerText(field, suggestion.name);
    setState(() {
      if (field == RouteFieldKind.from) {
        _fromSelection = suggestion;
      } else {
        _toSelection = suggestion;
      }
    });
    _clearSuggestions();
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
    return true;
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
    if (!mounted) return;
    if (_fromFocus.hasFocus) {
      if (_activeSuggestionField != RouteFieldKind.from) {
        setState(() => _activeSuggestionField = RouteFieldKind.from);
      }
      _requestSuggestions(RouteFieldKind.from, _fromCtrl.text);
    } else if (_toFocus.hasFocus) {
      if (_activeSuggestionField != RouteFieldKind.to) {
        setState(() => _activeSuggestionField = RouteFieldKind.to);
      }
      _requestSuggestions(RouteFieldKind.to, _toCtrl.text);
    } else {
      _clearSuggestions();
    }
    if ((_fromFocus.hasFocus || _toFocus.hasFocus) && _isSheetCollapsed) {
      final expTop = _lastComputedExpandedTop;
      final colTop = _lastComputedCollapsedTop;
      if (expTop != null && colTop != null) {
        _animateTo(expTop, colTop);
        _stopDragRumble();
      }
    }
  }

  // Pop is handled via PopScope in build()

  void _unfocusInputs() {
    FocusScope.of(context).unfocus();
    _clearSuggestions();
  }
}

/* class _PillButton extends StatefulWidget {
  const _PillButton({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;
  @override
  State<_PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<_PillButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.97 : 1.0,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _pressed ? const Color(0x14000000) : const Color(0x0F000000),
            border: Border.all(color: const Color(0x11000000)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: widget.child,
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatefulWidget {
  const _PrimaryButton({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;
  @override
  State<_PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<_PrimaryButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 80),
        scale: _pressed ? 0.985 : 1.0,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _pressed
                ? const Color.fromARGB(255, 0, 105, 124)
                : AppColors.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: widget.child,
        ),
      ),
    );
  }
}

class _BottomCard extends StatelessWidget {
  const _BottomCard({
    required this.isCollapsed,
    required this.collapseProgress,
    required this.onHandleTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.fromCtrl,
    required this.toCtrl,
    required this.fromFocusNode,
    required this.toFocusNode,
    required this.showMyLocationDefault,
    required this.onUnfocus,
  });

  final bool isCollapsed;
  final double collapseProgress; // 0.0 (expanded) -> 1.0 (collapsed)
  final VoidCallback onHandleTap;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate; // dy delta
  final ValueChanged<double> onDragEnd; // velocity dy
  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final FocusNode fromFocusNode;
  final FocusNode toFocusNode;
  final bool showMyLocationDefault;
  final VoidCallback onUnfocus;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000), // ~10% black
            blurRadius: 14,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onUnfocus,
        child: Listener(
          onPointerDown: (_) => onUnfocus(),
          child: SafeArea(
          top: false,
          child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle area
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
                      color: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
              ),
            ),

            // Title above the pickers; fade and collapse height progressively with drag
            Builder(builder: (context) {
              // Start fading the header from mid -> collapsed
              final fadeStart = 0.5;
              final t = ((collapseProgress - fadeStart) / (1 - fadeStart)).clamp(0.0, 1.0);
              final opacity = 1.0 - Curves.easeOut.transform(t);
              return GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: onUnfocus,
                child: ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    heightFactor: opacity, // shrink height as it fades
                    child: Opacity(
                      opacity: opacity,
                      child: const Padding(
                        padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Where to?',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF000000),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),

            // Field box (fixed padding; handle remains constant size)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: RouteFieldBox(
                fromController: fromCtrl,
                toController: toCtrl,
                fromFocusNode: fromFocusNode,
                toFocusNode: toFocusNode,
                showMyLocationDefault: showMyLocationDefault,
                accentColor: AppColors.accent,
              ),
            ),

            // Time and Search actions (expanded only)
            if (!isCollapsed)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Builder(
                  builder: (context) {
                    const double start = 0.5; // begin sliding near mid-drag
                    final double raw = (collapseProgress - start) / (1 - start);
                    final double t = raw.clamp(0.0, 1.0);
                    final double dy = 16.0 * t; // slight slide 0..16 px
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: onUnfocus,
                      child: Transform.translate(
                        offset: Offset(0, dy),
                        child: Row(
                          children: [
                            // Time selector (placeholder UI)
                            _PillButton(
                              onTap: () { onUnfocus(); },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(LucideIcons.clock, size: 16, color: Color(0xFF000000)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Now',
                                    style: TextStyle(
                                      color: Color(0xFF000000),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            // Search button (primary)
                            _PrimaryButton(
                              onTap: () {
                                onUnfocus();
                                final needsFrom = !showMyLocationDefault;
                                final fromEmpty = fromCtrl.text.trim().isEmpty;
                                final toEmpty = toCtrl.text.trim().isEmpty;
                                final invalid = (needsFrom && fromEmpty) || toEmpty;
                                if (invalid) {
                                  final msg = showMyLocationDefault
                                      ? 'Please enter a destination'
                                      : 'Please enter both locations';
                                  showValidationToast(context, msg);
                                  return;
                                }
                                try { Vibration.vibrate(duration: 18, amplitude: 200); } catch (_) {}
                                // TODO: Implement actual search action
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Text(
                                    'Search',
                                    style: TextStyle(
                                      color: Color(0xFFFFFFFF),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Suggestions only when expanded
            if (!isCollapsed) ...[
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'Suggestions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF000000),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: _SuggestionsList(
                    items: const [
                      _Suggestion(icon: LucideIcons.house, title: 'Home', subtitle: 'Save your home'),
                      _Suggestion(icon: LucideIcons.building, title: 'Work', subtitle: 'Save your workplace'),
                      _Suggestion(icon: LucideIcons.mapPin, title: 'Recent: Café', subtitle: 'Old Town, 1.2 km'),
                      _Suggestion(icon: LucideIcons.mapPin, title: 'Recent: Station', subtitle: 'Central Station'),
                    ],
                    onItemTap: onUnfocus,
                  ),
                ),
              ),
            ],
          ],
          ),
        ),
      ),
    ),
    );
  }
}

*/
