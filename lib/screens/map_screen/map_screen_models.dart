part of '../map_screen.dart';

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
  _VehicleMarker({required this.segmentData, required this.imageId});

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
  toggleAutoCenter,
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
