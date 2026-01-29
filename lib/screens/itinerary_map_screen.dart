import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../models/itinerary.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../utils/color_utils.dart';
import '../utils/duration_formatter.dart';
import '../utils/geo_utils.dart';
import '../utils/itinerary_leg_utils.dart';
import '../utils/leg_helper.dart';
import '../utils/map_marker_utils.dart';
import '../utils/polyline_utils.dart';
import '../utils/time_utils.dart';
import '../widgets/custom_app_bar.dart';

class ItineraryMapScreen extends StatefulWidget {
  final Itinerary itinerary;
  final bool showCarousel;

  const ItineraryMapScreen({
    super.key,
    required this.itinerary,
    this.showCarousel = true,
  });

  @override
  State<ItineraryMapScreen> createState() => _ItineraryMapScreenState();
}

class _ItineraryMapScreenState extends State<ItineraryMapScreen> {
  MapLibreMapController? _controller;
  final List<Line> _lines = [];
  final Set<String> _stopMarkerImages = {};
  Color? _stopAccentColor;
  bool _didAddStopsLayer = false;
  Future<void>? _stopsLayerInit;
  bool _isMapReady = false;
  late final PageController _pageController;
  int _currentPage = 0;
  List<List<LatLng>> _legGeometries = [];
  late final List<DisplayLegInfo> _displayLegs;

  static const double _transferZoomLevel = 16.5;
  static const double _transferDistanceThresholdMeters = 80.0;
  static const String _kStopsSourceId = 'itinerary-stops-source';
  static const String _kStopsLayerId = 'itinerary-stops-layer';
  static const double _walkLineWidth = 3.0;
  static const double _nonWalkLineWidth = 3.4;
  static const Color _walkLegColor = Color(0xFF9E9E9E);

  List<DisplayLegInfo> get _mapLegs {
    if (_displayLegs.isNotEmpty) return _displayLegs;
    return List<DisplayLegInfo>.generate(
      widget.itinerary.legs.length,
      (index) => DisplayLegInfo(
        leg: widget.itinerary.legs[index],
        originalIndex: index,
      ),
    );
  }

  List<Leg> _cameraLegs() => _mapLegs.map((entry) => entry.leg).toList();

  @override
  void initState() {
    super.initState();
    _displayLegs = buildDisplayLegs(widget.itinerary.legs);
    _pageController = PageController(
      viewportFraction: widget.showCarousel ? 0.86 : 1.0,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final color = AppColors.accentOf(context);
    if (_stopAccentColor == color) return;
    _stopAccentColor = color;
    if (_isMapReady) {
      unawaited(_ensureStopMarkerImageForColor(color));
      unawaited(_drawRouteStops());
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                CustomAppBar(
                  title: 'Journey Map',
                  onBackButtonPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: MapLibreMap(
                    onMapCreated: _onMapCreated,
                    styleString: context.watch<ThemeProvider>().mapStyleUrl,
                    initialCameraPosition: _calculateInitialCamera(),
                    myLocationEnabled: true,
                    myLocationRenderMode: MyLocationRenderMode.compass,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    compassEnabled: false,
                  ),
                ),
              ],
            ),
            if (widget.showCarousel)
              Positioned(
                left: 0,
                right: 0,
                bottom: 24,
                child: _buildJourneyCarousel(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildJourneyCarousel() {
    if (!widget.showCarousel) {
      return const SizedBox.shrink();
    }

    final totalItems = _displayLegs.length + 1;
    if (totalItems == 0) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 124,
          child: PageView.builder(
            controller: _pageController,
            physics: const BouncingScrollPhysics(),
            onPageChanged: _handlePageChanged,
            clipBehavior: Clip.none,
            padEnds: true,
            itemCount: totalItems,
            itemBuilder: (context, index) {
              return _buildCarouselItem(index, totalItems);
            },
          ),
        ),
        if (totalItems > 1) ...[
          const SizedBox(height: 12),
          _CarouselIndicator(itemCount: totalItems, activeIndex: _currentPage),
        ],
      ],
    );
  }

  Widget _buildCarouselItem(int index, int totalItems) {
    final padding = const EdgeInsets.symmetric(horizontal: 12);

    final Widget child;
    if (index == 0) {
      child = _JourneySummaryCard(itinerary: widget.itinerary);
    } else {
      final legIndex = index - 1;
      final entry = _displayLegs[legIndex];
      final leg = entry.leg;
      final accentColor = _getLegColorFromLeg(leg, entry.originalIndex);
      child = entry.isTransfer
          ? _TransferCarouselCard(leg: leg)
          : _LegCarouselCard(
              leg: leg,
              legIndex: legIndex,
              accentColor: accentColor,
            );
    }

    return Padding(
      padding: padding,
      child: Align(
        alignment: Alignment.center,
        child: SizedBox(width: double.infinity, child: child),
      ),
    );
  }

  void _handlePageChanged(int index) {
    if (_currentPage == index) return;
    setState(() => _currentPage = index);
    if (!_isMapReady) return;
    if (index == 0) {
      unawaited(_fitCameraToBounds());
    } else {
      unawaited(_focusLeg(index - 1));
    }
  }

  Future<void> _focusLeg(int legIndex) async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return;
    if (legIndex < 0 || legIndex >= _legGeometries.length) return;

    final geometry = _legGeometries[legIndex];
    if (geometry.isEmpty) return;

    if (geometry.length == 1) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(geometry.first, _transferZoomLevel),
      );
      return;
    }

    final isTransfer =
        legIndex < _displayLegs.length && _displayLegs[legIndex].isTransfer;

    double minLat = geometry.first.latitude;
    double maxLat = geometry.first.latitude;
    double minLon = geometry.first.longitude;
    double maxLon = geometry.first.longitude;

    for (final point in geometry) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLon) minLon = point.longitude;
      if (point.longitude > maxLon) maxLon = point.longitude;
    }

    final approxDistance = coordinateDistanceInMeters(
      geometry.first.latitude,
      geometry.first.longitude,
      geometry.last.latitude,
      geometry.last.longitude,
    );
    final shouldClampZoom =
        isTransfer || approxDistance <= _transferDistanceThresholdMeters;
    final center = LatLng((minLat + maxLat) / 2, (minLon + maxLon) / 2);

    if (shouldClampZoom) {
      await controller.animateCamera(
        CameraUpdate.newLatLngZoom(center, _transferZoomLevel),
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
        CameraUpdate.newLatLngZoom(geometry.first, _transferZoomLevel),
      );
    }
  }

  CameraPosition _calculateInitialCamera() {
    final legs = _cameraLegs();
    if (legs.isEmpty) {
      return const CameraPosition(target: LatLng(50.087, 14.420), zoom: 13.0);
    }

    double minLat = legs.first.fromLat;
    double maxLat = legs.first.fromLat;
    double minLon = legs.first.fromLon;
    double maxLon = legs.first.fromLon;

    for (final leg in legs) {
      if (leg.fromLat < minLat) minLat = leg.fromLat;
      if (leg.fromLat > maxLat) maxLat = leg.fromLat;
      if (leg.fromLon < minLon) minLon = leg.fromLon;
      if (leg.fromLon > maxLon) maxLon = leg.fromLon;
      if (leg.toLat < minLat) minLat = leg.toLat;
      if (leg.toLat > maxLat) maxLat = leg.toLat;
      if (leg.toLon < minLon) minLon = leg.toLon;
      if (leg.toLon > maxLon) maxLon = leg.toLon;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;
    return CameraPosition(target: LatLng(centerLat, centerLon), zoom: 13.0);
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;
    setState(() => _isMapReady = true);

    // Wait a bit for the map to fully initialize
    await Future.delayed(const Duration(milliseconds: 500));

    // Draw all the journey legs
    await _drawJourneyLegs();
    await _drawRouteStops();

    // Fit the camera to show all legs
    await _fitCameraToBounds();
    if (_currentPage > 0) {
      await _focusLeg(_currentPage - 1);
    }
  }

  Future<void> _drawJourneyLegs() async {
    final controller = _controller;
    if (controller == null || !_isMapReady) {
      return;
    }

    // Clear existing lines
    for (final line in _lines) {
      try {
        await controller.removeLine(line);
      } catch (_) {}
    }
    _lines.clear();
    final displayLegs = _mapLegs;
    if (displayLegs.isEmpty) return;

    final geometries = <List<LatLng>>[];

    for (int i = 0; i < displayLegs.length; i++) {
      final leg = displayLegs[i].leg;
      final color = _getLegColorFromLeg(leg, displayLegs[i].originalIndex);

      List<LatLng> geometry;
      if (leg.legGeometry != null && leg.legGeometry!.points.isNotEmpty) {
        try {
          geometry = decodePolyline(
            leg.legGeometry!.points,
            leg.legGeometry!.precision,
          );
        } catch (e) {
          geometry = [
            LatLng(leg.fromLat, leg.fromLon),
            LatLng(leg.toLat, leg.toLon),
          ];
        }
      } else {
        geometry = [
          LatLng(leg.fromLat, leg.fromLon),
          LatLng(leg.toLat, leg.toLon),
        ];
      }
      final storedGeometry = List<LatLng>.from(geometry);
      geometries.add(storedGeometry);

      try {
        final line = await controller.addLine(
          LineOptions(
            geometry: storedGeometry,
            lineColor: colorToHex(color),
            lineWidth: leg.mode == 'WALK' ? _walkLineWidth : _nonWalkLineWidth,
            lineOpacity: 0.8,
          ),
        );
        _lines.add(line);
      } catch (e) {
        // Handle error silently
      }
    }
    _legGeometries = geometries;
  }

  List<_RouteStop> _collectRouteStops() {
    final deduped = <String, _RouteStop>{};
    int order = 0;

    void addStop(double lat, double lon, Color color, bool isWalk) {
      final key = '${lat.toStringAsFixed(5)},${lon.toStringAsFixed(5)}';
      final existing = deduped[key];
      if (existing == null) {
        deduped[key] = _RouteStop(
          point: LatLng(lat, lon),
          color: color,
          order: order++,
          isWalk: isWalk,
        );
        return;
      }
      if (existing.isWalk && !isWalk) {
        deduped[key] = _RouteStop(
          point: existing.point,
          color: color,
          order: existing.order,
          isWalk: false,
        );
      }
    }

    for (final entry in _mapLegs) {
      final leg = entry.leg;
      final isWalk = leg.mode == 'WALK';
      final color = _getLegColorFromLeg(leg, entry.originalIndex);
      addStop(leg.fromLat, leg.fromLon, color, isWalk);
      for (final stop in leg.intermediateStops) {
        addStop(stop.lat, stop.lon, color, isWalk);
      }
      addStop(leg.toLat, leg.toLon, color, isWalk);
    }

    final stops = deduped.values.toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return stops;
  }

  Future<void> _drawRouteStops() async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return;
    await _ensureStopsLayer();
    if (!_didAddStopsLayer) return;

    final stops = _collectRouteStops();
    if (stops.isEmpty) {
      try {
        await controller.setGeoJsonSource(
          _kStopsSourceId,
          _emptyFeatureCollection(),
        );
      } catch (_) {}
      return;
    }

    final features = <Map<String, dynamic>>[];
    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final imageId = await _ensureStopMarkerImageForColor(stop.color);
      if (imageId == null) continue;
      features.add({
        'type': 'Feature',
        'id': i,
        'properties': {'iconId': imageId, 'order': stop.order},
        'geometry': {
          'type': 'Point',
          'coordinates': [stop.point.longitude, stop.point.latitude],
        },
      });
    }
    try {
      await controller.setGeoJsonSource(_kStopsSourceId, {
        'type': 'FeatureCollection',
        'features': features,
      });
    } catch (_) {}
  }

  String _stopMarkerImageIdForColor(Color color) {
    final hex = colorToHex(color).replaceAll('#', '');
    return 'itinerary-stop-marker-$hex';
  }

  Future<String?> _ensureStopMarkerImageForColor(Color color) async {
    final controller = _controller;
    if (controller == null) return null;
    final imageId = _stopMarkerImageIdForColor(color);
    if (_stopMarkerImages.contains(imageId)) {
      return imageId;
    }
    try {
      final image = await buildStopMarkerImage(color);
      await controller.addImage(imageId, image);
      _stopMarkerImages.add(imageId);
      return imageId;
    } catch (_) {
      return null;
    }
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

  Future<void> _ensureStopsLayer() async {
    if (_didAddStopsLayer) return;
    final inFlight = _stopsLayerInit;
    if (inFlight != null) return inFlight;
    final completer = Completer<void>();
    _stopsLayerInit = completer.future;
    final controller = _controller;
    try {
      if (controller == null || !_isMapReady) return;
      final color = _stopAccentColor ?? _currentAccentColor();
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
      final hasSource = sourceIds.contains(_kStopsSourceId);
      final hasLayer = layerIds.contains(_kStopsLayerId);
      if (!hasSource) {
        await controller.addGeoJsonSource(
          _kStopsSourceId,
          _emptyFeatureCollection(),
          promoteId: 'id',
        );
      }
      if (!hasLayer) {
        await controller.addSymbolLayer(
          _kStopsSourceId,
          _kStopsLayerId,
          SymbolLayerProperties(
            iconImage: [Expressions.get, 'iconId'],
            iconSize: _stopIconSizeExpression(),
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
            iconAnchor: 'center',
            symbolSortKey: [Expressions.get, 'order'],
          ),
          enableInteraction: false,
        );
      }
      _didAddStopsLayer = true;
    } catch (_) {
      _didAddStopsLayer = false;
    } finally {
      _stopsLayerInit = null;
      if (!completer.isCompleted) completer.complete();
    }
  }

  Color _getLegColorFromLeg(Leg leg, int _) {
    if (leg.mode == 'WALK') {
      return _walkLegColor;
    }
    final parsed = parseHexColor(leg.routeColor?.trim());
    return parsed ?? _currentAccentColor();
  }

  Color _currentAccentColor() {
    return ThemeProvider.instance?.accentColor ?? AppColors.accent;
  }

  Future<void> _fitCameraToBounds() async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return;

    await _fitCameraToItinerary(controller);
  }

  Future<void> _fitCameraToItinerary(MapLibreMapController controller) async {
    final legs = _cameraLegs();
    if (legs.isEmpty) return;

    double minLat = legs.first.fromLat;
    double maxLat = legs.first.fromLat;
    double minLon = legs.first.fromLon;
    double maxLon = legs.first.fromLon;

    for (final leg in legs) {
      if (leg.fromLat < minLat) minLat = leg.fromLat;
      if (leg.fromLat > maxLat) maxLat = leg.fromLat;
      if (leg.fromLon < minLon) minLon = leg.fromLon;
      if (leg.fromLon > maxLon) maxLon = leg.fromLon;
      if (leg.toLat < minLat) minLat = leg.toLat;
      if (leg.toLat > maxLat) maxLat = leg.toLat;
      if (leg.toLon < minLon) minLon = leg.toLon;
      if (leg.toLon > maxLon) maxLon = leg.toLon;
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
          top: 48,
          right: 48,
          bottom: 220,
        ),
      );
    } catch (_) {
      await controller.animateCamera(
        CameraUpdate.newLatLng(LatLng(legs.first.fromLat, legs.first.fromLon)),
      );
    }
  }
}

class _CarouselCard extends StatelessWidget {
  const _CarouselCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0x11000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _JourneySummaryCard extends StatelessWidget {
  const _JourneySummaryCard({required this.itinerary});

  final Itinerary itinerary;

  @override
  Widget build(BuildContext context) {
    final firstLeg = itinerary.legs.isNotEmpty ? itinerary.legs.first : null;
    final lastLeg = itinerary.legs.isNotEmpty ? itinerary.legs.last : null;
    return _CarouselCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Journey overview',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _JourneyTimeTile(
                  label: 'Departure',
                  actualTime: firstLeg?.startTime ?? itinerary.startTime,
                  scheduledTime: firstLeg?.scheduledStartTime,
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Icon(LucideIcons.clock, size: 20),
                    const SizedBox(height: 4),
                    Text(
                      formatDuration(itinerary.duration),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _JourneyTimeTile(
                    label: 'Arrival',
                    actualTime: lastLeg?.endTime ?? itinerary.endTime,
                    scheduledTime: lastLeg?.scheduledEndTime,
                    alignEnd: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RouteStop {
  const _RouteStop({
    required this.point,
    required this.color,
    required this.order,
    required this.isWalk,
  });

  final LatLng point;
  final Color color;
  final int order;
  final bool isWalk;
}

class _LegCarouselCard extends StatelessWidget {
  const _LegCarouselCard({
    required this.leg,
    required this.legIndex,
    required this.accentColor,
  });

  final Leg leg;
  final int legIndex;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final headline = _resolveHeadline(leg);
    final subtitle = _resolveSubtitle(leg);

    return _CarouselCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Text(
            headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.black.withValues(alpha: 0.4),
            ),
          ),
          const SizedBox(height: 12),
          _LegStopRow(
            icon: LucideIcons.circleDot,
            actualTime: leg.startTime,
            scheduledTime: leg.scheduledStartTime,
            label: leg.fromName,
          ),
          const SizedBox(height: 6),
          _LegStopRow(
            icon: LucideIcons.flag,
            actualTime: leg.endTime,
            scheduledTime: leg.scheduledEndTime,
            label: leg.toName,
          ),
        ],
      ),
    );
  }

  String _resolveHeadline(Leg leg) {
    if (leg.displayName != null && leg.displayName!.isNotEmpty) {
      return leg.displayName!;
    }
    if (leg.routeShortName != null && leg.routeShortName!.isNotEmpty) {
      if (leg.headsign != null && leg.headsign!.isNotEmpty) {
        return '${leg.routeShortName} • ${leg.headsign}';
      }
      return leg.routeShortName!;
    }
    if (leg.routeLongName != null && leg.routeLongName!.isNotEmpty) {
      return leg.routeLongName!;
    }
    if (leg.headsign != null && leg.headsign!.isNotEmpty) {
      return leg.headsign!;
    }
    return getTransitModeName(leg.mode);
  }

  String _resolveSubtitle(Leg leg) {
    final mode = getTransitModeName(leg.mode);
    if (leg.headsign != null && leg.headsign!.isNotEmpty) {
      return '$mode • ${leg.headsign}';
    }
    if (leg.routeLongName != null && leg.routeLongName!.isNotEmpty) {
      return '$mode • ${leg.routeLongName}';
    }
    if (leg.routeShortName != null && leg.routeShortName!.isNotEmpty) {
      return '$mode • ${leg.routeShortName}';
    }
    return mode;
  }
}

class _TransferCarouselCard extends StatelessWidget {
  const _TransferCarouselCard({required this.leg});

  final Leg leg;

  @override
  Widget build(BuildContext context) {
    final depDelay = computeDelay(leg.scheduledStartTime, leg.startTime);
    final arrDelay = computeDelay(leg.scheduledEndTime, leg.endTime);
    final depTime = formatTime(leg.scheduledStartTime ?? leg.startTime);
    final arrTime = formatTime(leg.scheduledEndTime ?? leg.endTime);
    return _CarouselCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.arrowLeftRight, size: 20),
              const SizedBox(width: 8),
              Text(
                'Transfer',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const Spacer(),
              Text(
                formatDuration(leg.duration),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(LucideIcons.arrowRight, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      depTime,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    if (depDelay != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        formatDelay(depDelay),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: delayColor(depDelay),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        leg.fromName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.black.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (leg.distance != null && leg.distance! > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Approx. ${(leg.distance! / 1000).toStringAsFixed(2)} km walk',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(LucideIcons.arrowDown, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Row(
                  children: [
                    Text(
                      arrTime,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    if (arrDelay != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        formatDelay(arrDelay),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: delayColor(arrDelay),
                        ),
                      ),
                    ],
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        leg.toName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.black.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _JourneyTimeTile extends StatelessWidget {
  const _JourneyTimeTile({
    required this.label,
    required this.actualTime,
    this.scheduledTime,
    this.alignEnd = false,
  });

  final String label;
  final DateTime actualTime;
  final DateTime? scheduledTime;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    final displayTime = formatTime(scheduledTime ?? actualTime);
    final delay = computeDelay(scheduledTime, actualTime);
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.black.withValues(alpha: 0.4),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              displayTime,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.black,
              ),
            ),
            if (delay != null) ...[
              const SizedBox(width: 6),
              Text(
                formatDelay(delay),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: delayColor(delay),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class _LegStopRow extends StatelessWidget {
  const _LegStopRow({
    required this.icon,
    required this.actualTime,
    required this.label,
    this.scheduledTime,
  });

  final IconData icon;
  final DateTime actualTime;
  final DateTime? scheduledTime;
  final String label;

  @override
  Widget build(BuildContext context) {
    final displayTime = formatTime(scheduledTime ?? actualTime);
    final delay = computeDelay(scheduledTime, actualTime);
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.black.withValues(alpha: 0.4)),
        const SizedBox(width: 8),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: displayTime,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
              if (delay != null)
                TextSpan(
                  text: ' ${formatDelay(delay)}',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: delayColor(delay),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppColors.black.withValues(alpha: 0.6),
            ),
          ),
        ),
      ],
    );
  }
}

class _CarouselIndicator extends StatelessWidget {
  const _CarouselIndicator({
    required this.itemCount,
    required this.activeIndex,
  });

  final int itemCount;
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < itemCount; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  height: 6,
                  width: i == activeIndex ? 16 : 6,
                  decoration: BoxDecoration(
                    color: i == activeIndex
                        ? accent
                        : accent.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
