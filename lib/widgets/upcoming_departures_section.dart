import 'dart:async';

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/stop_time.dart';
import '../services/stop_times_service.dart';
import '../services/transitous_map_service.dart';
import '../theme/app_colors.dart';
import '../utils/color_utils.dart';
import '../utils/stop_time_utils.dart';
import '../utils/time_utils.dart';
import 'gtfs_fields_row.dart';
import 'skeletons/skeleton_shimmer.dart';

class UpcomingDeparturesSection extends StatefulWidget {
  const UpcomingDeparturesSection({
    super.key,
    required this.stops,
    required this.onStopTap,
  });

  final List<MapStop> stops;
  final ValueChanged<MapStop> onStopTap;

  @override
  State<UpcomingDeparturesSection> createState() =>
      _UpcomingDeparturesSectionState();
}

class _UpcomingDeparturesSectionState
    extends State<UpcomingDeparturesSection> {
  static const Duration _refreshInterval = Duration(seconds: 30);
  static const int _departuresPerStop = 3;

  Timer? _refreshTimer;
  int _requestId = 0;
  bool _isLoading = true;
  Map<String, List<StopTime>> _departuresByStopId = {};

  @override
  void initState() {
    super.initState();
    unawaited(_load());
    _refreshTimer = Timer.periodic(_refreshInterval, (_) => _load());
  }

  @override
  void didUpdateWidget(covariant UpcomingDeparturesSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldIds = oldWidget.stops.map((s) => s.stopId).toList();
    final newIds = widget.stops.map((s) => s.stopId).toList();
    if (!listEquals(oldIds, newIds)) {
      unawaited(_load());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  DateTime? _departureKey(StopTime stopTime) {
    return stopTime.place.departure ??
        stopTime.place.scheduledDeparture ??
        stopTime.place.arrival ??
        stopTime.place.scheduledArrival;
  }

  /// Some backends (MOTIS included) split one physical stop into several
  /// nearby stop IDs (separate platforms/directions, or just duplicate
  /// entries) that end up serving the exact same departures — rather than
  /// merging them into one stop themselves. Two stops with the same name
  /// and the same trips at the same times are almost certainly that same
  /// physical stop, so only the first (nearest) one is kept.
  String _departuresSignature(List<StopTime> departures) {
    return departures
        .map((d) => '${d.tripId}@${_departureKey(d)?.toIso8601String()}')
        .join('|');
  }

  Future<void> _load() async {
    final stops = widget.stops;
    final requestId = ++_requestId;

    if (stops.isEmpty) {
      if (!mounted) return;
      setState(() {
        _departuresByStopId = {};
        _isLoading = false;
      });
      return;
    }

    if (mounted && _departuresByStopId.isEmpty) {
      setState(() => _isLoading = true);
    }

    final now = DateTime.now();
    final results = await Future.wait(
      stops.map((stop) async {
        final stopId = stop.stopId;
        if (stopId == null || stopId.isEmpty) return null;
        try {
          final response = await StopTimesService.fetchStopTimes(
            stopId: stopId,
            n: _departuresPerStop,
            startTime: now,
          );
          final deduped = deduplicateStopTimes(response.stopTimes);
          final filtered =
              deduped.where((entry) {
                  final time = _departureKey(entry);
                  return time != null &&
                      time.isAfter(now.subtract(const Duration(minutes: 1)));
                }).toList()
                ..sort(
                  (a, b) => _departureKey(a)!.compareTo(_departureKey(b)!),
                );
          if (filtered.isEmpty) return null;
          return MapEntry(stopId, filtered.take(_departuresPerStop).toList());
        } catch (_) {
          return null;
        }
      }),
    );

    if (!mounted || requestId != _requestId) return;
    final map = <String, List<StopTime>>{
      for (final entry in results)
        if (entry != null) entry.key: entry.value,
    };
    setState(() {
      _departuresByStopId = map;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.stops.isEmpty) {
      return const _EmptyMessage(
        message: 'Move the map to see nearby departures.',
      );
    }
    if (_isLoading && _departuresByStopId.isEmpty) {
      return const _DeparturesSkeleton();
    }
    final stopsWithDepartures = widget.stops
        .where((s) => (_departuresByStopId[s.stopId]?.isNotEmpty ?? false))
        .toList();

    final seenSignatures = <String>{};
    final dedupedStops = [
      for (final stop in stopsWithDepartures)
        if (seenSignatures.add(
          '${stop.name.trim().toLowerCase()}::${_departuresSignature(_departuresByStopId[stop.stopId] ?? const [])}',
        ))
          stop,
    ];

    if (dedupedStops.isEmpty) {
      return const _EmptyMessage(
        message: 'No upcoming departures for stops in view.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final stop in dedupedStops) ...[
          _StopDeparturesGroup(
            stop: stop,
            departures: _departuresByStopId[stop.stopId] ?? const [],
            onTap: () => widget.onStopTap(stop),
          ),
          const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _StopDeparturesGroup extends StatelessWidget {
  const _StopDeparturesGroup({
    required this.stop,
    required this.departures,
    required this.onTap,
  });

  final MapStop stop;
  final List<StopTime> departures;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.black.withValues(alpha: 0.06)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.mapPin,
                  size: 16,
                  color: AppColors.accentOf(context),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    stop.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: AppColors.black.withValues(alpha: 0.3),
                ),
              ],
            ),
            GtfsFieldsRow(fields: {'stop': stop.stopId}),
            const SizedBox(height: 10),
            for (int i = 0; i < departures.length; i++) ...[
              _DepartureRow(stopTime: departures[i]),
              if (i != departures.length - 1) const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

class _DepartureRow extends StatelessWidget {
  const _DepartureRow({required this.stopTime});

  final StopTime stopTime;

  @override
  Widget build(BuildContext context) {
    final routeColor =
        parseHexColor(stopTime.routeColor) ?? AppColors.accentOf(context);
    final routeTextColor =
        parseHexColor(stopTime.routeTextColor) ?? AppColors.solidWhite;
    final departure = formatTime(
      stopTime.place.departure ?? stopTime.place.scheduledDeparture,
    );
    final label = stopTime.displayName.isNotEmpty
        ? stopTime.displayName
        : stopTime.routeShortName;

    return Row(
      children: [
        Container(
          constraints: const BoxConstraints(minWidth: 28),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          decoration: BoxDecoration(
            color: routeColor,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: routeTextColor,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            stopTime.headsign,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          departure,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.black,
          ),
        ),
      ],
    );
  }
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.clock, size: 24, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            'No departures to show',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.black.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeparturesSkeleton extends StatelessWidget {
  const _DeparturesSkeleton();

  @override
  Widget build(BuildContext context) {
    return SkeletonShimmer(
      baseColor: AppColors.black.withValues(alpha: 0.08),
      highlightColor: AppColors.black.withValues(alpha: 0.04),
      child: Column(
        children: List.generate(
          2,
          (index) => Padding(
            padding: EdgeInsets.only(bottom: index == 1 ? 0 : 12),
            child: Container(
              height: 84,
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
