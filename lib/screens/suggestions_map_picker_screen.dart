import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../services/transitous_geocode_service.dart';
import '../theme/app_colors.dart';
import '../utils/geo_utils.dart';
import '../utils/haptics.dart';
import '../utils/itinerary_navigation.dart';
import '../utils/map_marker_utils.dart';
import '../widgets/custom_app_bar.dart';

/// Full-screen map showing every current geocode suggestion as a numbered
/// pin, so the user can pick visually instead of from name/subtitle text
/// alone. Pops with the tapped [TransitousLocationSuggestion], or null if
/// the user backs out without picking one.
class SuggestionsMapPickerScreen extends StatefulWidget {
  const SuggestionsMapPickerScreen({
    super.key,
    required this.suggestions,
    this.title = 'Choose on map',
    this.userLocation,
  });

  final List<TransitousLocationSuggestion> suggestions;
  final String title;

  /// The user's current position, if known — used to show a straight-line
  /// distance on each suggestion chip.
  final LatLng? userLocation;

  @override
  State<SuggestionsMapPickerScreen> createState() =>
      _SuggestionsMapPickerScreenState();
}

class _SuggestionsMapPickerScreenState
    extends State<SuggestionsMapPickerScreen> {
  static const String _kMarkerImageIdPrefix = 'suggestion-map-marker-';
  static const String _kSourceId = 'suggestion-map-source';
  static const String _kLayerId = 'suggestion-map-layer';
  static const LatLng _kFallbackTarget = LatLng(50.087, 14.420);

  MapLibreMapController? _controller;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                CustomAppBar(
                  title: widget.title,
                  onBackButtonPressed: () => Navigator.of(context).pop(),
                ),
                Expanded(
                  child: MapLibreMap(
                    onMapCreated: _onMapCreated,
                    onStyleLoadedCallback: _onStyleLoaded,
                    styleString: themeProvider.mapStyleUrl,
                    initialCameraPosition: _initialCamera(),
                    rotateGesturesEnabled: true,
                    tiltGesturesEnabled: false,
                    compassEnabled: false,
                  ),
                ),
              ],
            ),
            if (widget.suggestions.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: _buildChipStrip(),
              ),
          ],
        ),
      ),
    );
  }

  CameraPosition _initialCamera() {
    if (widget.suggestions.isEmpty) {
      return const CameraPosition(target: _kFallbackTarget, zoom: 13.0);
    }
    if (widget.suggestions.length == 1) {
      return CameraPosition(
        target: widget.suggestions.first.latLng,
        zoom: 15.0,
      );
    }
    final bounds = _boundsFor(widget.suggestions);
    return CameraPosition(
      target: LatLng(
        (bounds.southwest.latitude + bounds.northeast.latitude) / 2,
        (bounds.southwest.longitude + bounds.northeast.longitude) / 2,
      ),
      zoom: 12.0,
    );
  }

  void _onMapCreated(MapLibreMapController controller) {
    _controller = controller;
    controller.onFeatureTapped.add(_handleFeatureTapped);
  }

  Future<void> _onStyleLoaded() async {
    await _plotSuggestions();
    if (widget.suggestions.length > 1) {
      unawaited(_fitToSuggestions());
    }
  }

  /// Plots suggestions as a GeoJSON source + symbol layer, the same pattern
  /// [ItineraryMapScreen] uses for its stop markers — the annotation-based
  /// `addSymbol` API this screen used previously requires the map's
  /// annotation managers, and silently dropped every marker with nothing
  /// but a caught, easy-to-miss log line when that wasn't set up the way it
  /// expected, leaving the map blank with no visible error. Each marker's
  /// number is baked directly into its icon image (via [buildNumberedMarkerImage])
  /// rather than layered on top with the layer's own `textField` — the same
  /// recipe the main map's live vehicle markers use, since a symbol layer's
  /// `textField` depends on the style having glyphs available and silently
  /// drops the whole symbol without them.
  Future<void> _plotSuggestions() async {
    final controller = _controller;
    if (controller == null || widget.suggestions.isEmpty) return;

    try {
      final accent = AppColors.accentOf(context);
      final features = <Map<String, dynamic>>[];
      for (int i = 0; i < widget.suggestions.length; i++) {
        final imageId = '$_kMarkerImageIdPrefix$i';
        final image = await buildNumberedMarkerImage(accent, '${i + 1}');
        await controller.addImage(imageId, image);
        features.add({
          'type': 'Feature',
          'id': i,
          'properties': {'iconId': imageId},
          'geometry': {
            'type': 'Point',
            'coordinates': [
              widget.suggestions[i].lon,
              widget.suggestions[i].lat,
            ],
          },
        });
      }
      final collection = {'type': 'FeatureCollection', 'features': features};

      final sourceIds = (await controller.getSourceIds()).cast<String>().toSet();
      if (sourceIds.contains(_kSourceId)) {
        await controller.setGeoJsonSource(_kSourceId, collection);
      } else {
        await controller.addGeoJsonSource(
          _kSourceId,
          collection,
          promoteId: 'id',
        );
      }

      final layerIds = (await controller.getLayerIds()).cast<String>().toSet();
      if (!layerIds.contains(_kLayerId)) {
        await controller.addSymbolLayer(
          _kSourceId,
          _kLayerId,
          SymbolLayerProperties(
            iconImage: [Expressions.get, 'iconId'],
            iconSize: 1.0,
            iconAnchor: 'center',
            iconAllowOverlap: true,
            iconIgnorePlacement: true,
          ),
          enableInteraction: true,
        );
      }
    } catch (error, stackTrace) {
      developer.log(
        'Failed to plot suggestion markers',
        name: 'SuggestionsMapPickerScreen',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _fitToSuggestions() async {
    final controller = _controller;
    if (controller == null) return;
    final bounds = _boundsFor(widget.suggestions);
    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          bounds,
          left: 48,
          top: 48,
          right: 48,
          bottom: 140,
        ),
      );
    } catch (_) {}
  }

  void _handleFeatureTapped(
    math.Point<double> point,
    LatLng coordinate,
    String id,
    String layerId,
    Annotation? annotation,
  ) {
    if (layerId != _kLayerId) return;
    final index = int.tryParse(id);
    if (index == null) return;
    _selectSuggestion(index);
  }

  void _selectSuggestion(int index) {
    if (index < 0 || index >= widget.suggestions.length) return;
    unawaited(Haptics.lightTick());
    Navigator.of(context).pop(widget.suggestions[index]);
  }

  Widget _buildChipStrip() {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: widget.suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return _SuggestionChip(
            index: index,
            suggestion: widget.suggestions[index],
            userLocation: widget.userLocation,
            onTap: () => _selectSuggestion(index),
          );
        },
      ),
    );
  }
}

LatLngBounds _boundsFor(List<TransitousLocationSuggestion> suggestions) {
  double minLat = suggestions.first.lat;
  double maxLat = suggestions.first.lat;
  double minLon = suggestions.first.lon;
  double maxLon = suggestions.first.lon;
  for (final suggestion in suggestions) {
    if (suggestion.lat < minLat) minLat = suggestion.lat;
    if (suggestion.lat > maxLat) maxLat = suggestion.lat;
    if (suggestion.lon < minLon) minLon = suggestion.lon;
    if (suggestion.lon > maxLon) maxLon = suggestion.lon;
  }
  return LatLngBounds(
    southwest: LatLng(minLat, minLon),
    northeast: LatLng(maxLat, maxLon),
  );
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.index,
    required this.suggestion,
    required this.userLocation,
    required this.onTap,
  });

  final int index;
  final TransitousLocationSuggestion suggestion;
  final LatLng? userLocation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final location = userLocation;
    final distanceLabel = location == null
        ? null
        : formatWalkRemaining(
            coordinateDistanceInMeters(
              location.latitude,
              location.longitude,
              suggestion.lat,
              suggestion.lon,
            ),
          );
    final detailParts = [
      if (suggestion.subtitle.isNotEmpty) suggestion.subtitle,
      if (distanceLabel != null) distanceLabel,
    ];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.black.withValues(alpha: 0.1)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1F000000),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: AppColors.solidWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (detailParts.isNotEmpty)
                    Text(
                      detailParts.join(' • '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.black.withValues(alpha: 0.5),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
