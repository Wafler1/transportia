import 'dart:math' as math;
import 'package:flutter/widgets.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import '../models/itinerary.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';

class ItineraryMapScreen extends StatefulWidget {
  final Itinerary itinerary;

  const ItineraryMapScreen({super.key, required this.itinerary});

  @override
  State<ItineraryMapScreen> createState() => _ItineraryMapScreenState();
}

class _ItineraryMapScreenState extends State<ItineraryMapScreen> {
  static const _styleUrl = "https://tiles.openfreemap.org/styles/liberty";
  MapLibreMapController? _controller;
  final List<Line> _lines = [];
  bool _isMapReady = false;

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
                    styleString: _styleUrl,
                    initialCameraPosition: _calculateInitialCamera(),
                    myLocationEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    compassEnabled: false,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  CameraPosition _calculateInitialCamera() {
    // Calculate the center point of the journey
    final allLegs = widget.itinerary.legs;
    if (allLegs.isEmpty) {
      return const CameraPosition(
        target: LatLng(50.087, 14.420),
        zoom: 13.0,
      );
    }

    double minLat = allLegs.first.fromLat;
    double maxLat = allLegs.first.fromLat;
    double minLon = allLegs.first.fromLon;
    double maxLon = allLegs.first.fromLon;

    for (final leg in allLegs) {
      // Check from coordinates
      if (leg.fromLat < minLat) minLat = leg.fromLat;
      if (leg.fromLat > maxLat) maxLat = leg.fromLat;
      if (leg.fromLon < minLon) minLon = leg.fromLon;
      if (leg.fromLon > maxLon) maxLon = leg.fromLon;

      // Check to coordinates
      if (leg.toLat < minLat) minLat = leg.toLat;
      if (leg.toLat > maxLat) maxLat = leg.toLat;
      if (leg.toLon < minLon) minLon = leg.toLon;
      if (leg.toLon > maxLon) maxLon = leg.toLon;
    }

    final centerLat = (minLat + maxLat) / 2;
    final centerLon = (minLon + maxLon) / 2;

    return CameraPosition(
      target: LatLng(centerLat, centerLon),
      zoom: 13.0,
    );
  }

  Future<void> _onMapCreated(MapLibreMapController controller) async {
    _controller = controller;
    setState(() => _isMapReady = true);

    // Wait a bit for the map to fully initialize
    await Future.delayed(const Duration(milliseconds: 500));

    // Draw all the journey legs
    await _drawJourneyLegs();

    // Fit the camera to show all legs
    await _fitCameraToBounds();
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

    // Draw each leg
    for (int i = 0; i < widget.itinerary.legs.length; i++) {
      final leg = widget.itinerary.legs[i];
      final color = _getLegColor(leg, i);


      // Use encoded polyline if available, otherwise fall back to straight line
      List<LatLng> geometry;
      if (leg.legGeometry != null && leg.legGeometry!.points.isNotEmpty) {

        try {
          geometry = _decodePolyline(
            leg.legGeometry!.points,
            leg.legGeometry!.precision,
          );
          if (geometry.isNotEmpty) {
          }
        } catch (e) {
          // Fallback to straight line on decode error
          geometry = [
            LatLng(leg.fromLat, leg.fromLon),
            LatLng(leg.toLat, leg.toLon),
          ];
        }
      } else {
        // Fallback to straight line
        geometry = [
          LatLng(leg.fromLat, leg.fromLon),
          LatLng(leg.toLat, leg.toLon),
        ];
      }

      // Create a line for this leg
      try {
        final line = await controller.addLine(
          LineOptions(
            geometry: geometry,
            lineColor: _colorToHex(color),
            lineWidth: leg.mode == 'WALK' ? 3.0 : 5.0,
            lineOpacity: 0.8,
          ),
        );
        _lines.add(line);
      } catch (e) {
      }
    }
  }

  /// Decode an encoded polyline string to a list of LatLng coordinates
  /// Uses the Encoded Polyline Algorithm Format
  List<LatLng> _decodePolyline(String encoded, int precision) {
    final List<LatLng> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;
    // Use power of 10 for precision, not power of 2
    final double factor = math.pow(10, -precision).toDouble();

    while (index < encoded.length) {
      // Decode latitude
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

      // Decode longitude
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

  Color _getLegColor(Leg leg, int index) {
    // If the leg has a route color, use it
    if (leg.routeColor != null) {
      final parsed = _parseHexColor(leg.routeColor);
      if (parsed != null) return parsed;
    }

    // For WALK legs, use a darker shade
    if (leg.mode == 'WALK') {
      return const Color(0xFF666666);
    }

    // Use different shades of the accent color for different legs
    final baseColor = AppColors.accent;
    final shadeFactors = [1.0, 0.7, 0.5, 0.3];
    final shadeFactor = shadeFactors[index % shadeFactors.length];

    return Color.fromARGB(
      255,
      ((baseColor.r * 255.0).round() * shadeFactor).round(),
      ((baseColor.g * 255.0).round() * shadeFactor).round(),
      ((baseColor.b * 255.0).round() * shadeFactor).round(),
    );
  }

  Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    var cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) cleaned = 'FF' + cleaned;
    if (cleaned.length != 8) return null;
    return Color(int.parse('0x$cleaned'));
  }

  String _colorToHex(Color color) {
    final r = (color.r * 255.0).round();
    final g = (color.g * 255.0).round();
    final b = (color.b * 255.0).round();
    return '#${r.toRadixString(16).padLeft(2, '0')}${g.toRadixString(16).padLeft(2, '0')}${b.toRadixString(16).padLeft(2, '0')}';
  }

  Future<void> _fitCameraToBounds() async {
    final controller = _controller;
    if (controller == null || !_isMapReady) return;

    final allLegs = widget.itinerary.legs;
    if (allLegs.isEmpty) return;

    double minLat = allLegs.first.fromLat;
    double maxLat = allLegs.first.fromLat;
    double minLon = allLegs.first.fromLon;
    double maxLon = allLegs.first.fromLon;

    for (final leg in allLegs) {
      // Check from coordinates
      if (leg.fromLat < minLat) minLat = leg.fromLat;
      if (leg.fromLat > maxLat) maxLat = leg.fromLat;
      if (leg.fromLon < minLon) minLon = leg.fromLon;
      if (leg.fromLon > maxLon) maxLon = leg.fromLon;

      // Check to coordinates
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
          bottom: 48,
        ),
      );
    } catch (_) {
      // If bounds fitting fails, just center on the first point
      await controller.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(allLegs.first.fromLat, allLegs.first.fromLon),
        ),
      );
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}
