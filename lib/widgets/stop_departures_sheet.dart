import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/stop_time.dart';
import '../screens/connection_info_screen.dart';
import '../services/stop_times_service.dart';
import '../theme/app_colors.dart';
import '../utils/color_utils.dart';
import '../utils/custom_page_route.dart';
import '../utils/leg_helper.dart';
import '../utils/time_utils.dart';
import 'bottom_overlay_card.dart';
import 'pressable_highlight.dart';
import 'skeletons/skeleton_shimmer.dart';

/// Bottom sheet shown when a stop in the itinerary (or on the map) is
/// tapped. Shows a live list of the stop's upcoming departures. Tolerant of
/// a missing [stopId] and of empty/failed departures responses.
class StopDeparturesSheet extends StatefulWidget {
  const StopDeparturesSheet({
    super.key,
    required this.stopId,
    required this.stopName,
    required this.referenceTime,
    required this.onDismiss,
  });

  final String? stopId;
  final String stopName;
  final DateTime referenceTime;
  final VoidCallback onDismiss;

  @override
  State<StopDeparturesSheet> createState() => _StopDeparturesSheetState();
}

class _StopDeparturesSheetState extends State<StopDeparturesSheet> {
  List<StopTime>? _departures;
  bool _isLoading = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadDepartures());
  }

  Future<void> _loadDepartures() async {
    final stopId = widget.stopId;
    if (stopId == null || stopId.isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final response = await StopTimesService.fetchStopTimes(
        stopId: stopId,
        n: 8,
        startTime: widget.referenceTime,
      );
      if (!mounted) return;
      setState(() {
        _departures = response.stopTimes;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _departures = const [];
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _openConnection(String tripId) {
    if (tripId.isEmpty) return;
    widget.onDismiss();
    Navigator.of(
      context,
    ).push(CustomPageRoute(child: ConnectionInfoScreen(tripId: tripId)));
  }

  @override
  Widget build(BuildContext context) {
    return BottomOverlayCard(
      title: widget.stopName,
      onDismiss: widget.onDismiss,
      maxHeightFactor: 0.75,
      child: Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const _SectionLabel('Upcoming departures'),
              const SizedBox(height: 8),
              _buildDeparturesList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeparturesList() {
    if (widget.stopId == null || widget.stopId!.isEmpty) {
      return const _EmptyNote('No live departures available for this stop.');
    }
    if (_isLoading) {
      return const _DeparturesLoadingSkeleton();
    }
    final departures = _departures;
    if (departures == null || departures.isEmpty) {
      return _EmptyNote(
        _hasError
            ? 'Could not load upcoming departures.'
            : 'No upcoming departures found.',
      );
    }
    return Column(
      children: departures
          .map(
            (stopTime) => _DepartureTile(
              stopTime: stopTime,
              onTap: () => _openConnection(stopTime.tripId),
            ),
          )
          .toList(),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: AppColors.black.withValues(alpha: 0.5),
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Text(
        message,
        style: TextStyle(
          fontSize: 14,
          color: AppColors.black.withValues(alpha: 0.5),
        ),
      ),
    );
  }
}

class _DeparturesLoadingSkeleton extends StatelessWidget {
  const _DeparturesLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      child: Column(
        children: List.generate(
          3,
          (_) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E7EC),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }
}

class _DepartureTile extends StatelessWidget {
  const _DepartureTile({required this.stopTime, required this.onTap});

  final StopTime stopTime;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final place = stopTime.place;
    final badgeColor = parseHexColorOrAccent(context, stopTime.routeColor);
    final badgeTextColor =
        parseHexColor(stopTime.routeTextColor) ?? AppColors.solidWhite;
    final departure = place.scheduledDeparture ?? place.departure;
    final actualDeparture = place.departure;
    final delay = (departure != null && actualDeparture != null)
        ? computeDelay(departure, actualDeparture)
        : null;

    return PressableHighlight(
      onPressed: onTap,
      borderRadius: BorderRadius.circular(12),
      enableHaptics: false,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        child: Row(
          children: [
            Icon(
              getLegIcon(stopTime.mode),
              size: 20,
              color: AppColors.black.withValues(alpha: 0.5),
            ),
            const SizedBox(width: 10),
            if (stopTime.displayName.isNotEmpty) ...[
              Container(
                constraints: const BoxConstraints(minWidth: 30),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  stopTime.displayName,
                  style: TextStyle(
                    color: badgeTextColor,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                stopTime.headsign,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatTime(departure, nullPlaceholder: '--:--'),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
                if (delay != null)
                  Text(
                    formatDelay(delay),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: delayColor(delay),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
