import 'package:entaria_app/models/itinerary.dart';
import 'package:entaria_app/utils/duration_formatter.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';
import 'package:timelines_plus/timelines_plus.dart';
import '../models/trip_details.dart';
import '../services/trip_details_service.dart';
import '../theme/app_colors.dart';
import '../utils/leg_helper.dart' show getLegIcon, getTransitModeName;
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_card.dart';

class ConnectionInfoScreen extends StatefulWidget {
  final String tripId;

  const ConnectionInfoScreen({
    super.key,
    required this.tripId,
  });

  @override
  State<ConnectionInfoScreen> createState() => _ConnectionInfoScreenState();
}

class _ConnectionInfoScreenState extends State<ConnectionInfoScreen> {
  TripDetailsResponse? _tripDetails;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchTripDetails();
  }

  Future<void> _fetchTripDetails() async {
    try {
      final details = await TripDetailsService.fetchTripDetails(
        tripId: widget.tripId,
      );
      if (mounted) {
        setState(() {
          _tripDetails = details;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Color _parseHexColor(String? hexString) {
    if (hexString == null) return AppColors.accent;
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return AppColors.accent;
    }
  }

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  // Helper to check if two times are in the same minute
  bool _isSameMinute(DateTime a, DateTime b) {
    // Convert both to local time to ensure proper comparison
    final aLocal = a.toLocal();
    final bLocal = b.toLocal();
    return aLocal.year == bLocal.year &&
           aLocal.month == bLocal.month &&
           aLocal.day == bLocal.day &&
           aLocal.hour == bLocal.hour &&
           aLocal.minute == bLocal.minute;
  }

  // Estimate where the vehicle is based on current time and schedule
  // Returns: (stopIndex, isAtStation)
  // stopIndex: which stop the vehicle is at/passed
  // isAtStation: true if vehicle is currently at a station, false if between stations
  (int, bool) _estimateVehiclePosition(List<TripPlace> allStops) {
    final now = DateTime.now();

    // Check if trip hasn't started yet
    final firstStop = allStops.first;
    final firstDeparture = firstStop.departure ?? firstStop.arrival;
    if (firstDeparture != null && !_isSameMinute(now, firstDeparture) && now.isBefore(firstDeparture)) {
      return (-1, false); // Trip hasn't started, don't show vehicle
    }

    // Check if trip has ended
    final lastStop = allStops.last;
    final lastArrival = lastStop.arrival ?? lastStop.departure;
    if (lastArrival != null && !_isSameMinute(now, lastArrival) && now.isAfter(lastArrival)) {
      return (allStops.length, false); // Trip has ended, don't show vehicle
    }

    for (int i = 0; i < allStops.length; i++) {
      final stop = allStops[i];
      final arrival = stop.arrival;
      final departure = stop.departure;

      // Check if vehicle is at this station
      // Vehicle is at station if:
      // 1. Current time is in the same minute as departure time (vehicle hasn't left yet)
      // 2. OR current time is between arrival and departure
      if (departure != null && _isSameMinute(now, departure)) {
        return (i, true); // At this station (current time matches departure minute)
      }

      if (arrival != null && departure != null) {
        if (now.isAfter(arrival) && now.isBefore(departure)) {
          return (i, true); // At this station (between arrival and departure)
        }
      }

      // Check if vehicle hasn't reached this stop yet
      final nextTime = departure ?? arrival;
      if (nextTime != null && now.isBefore(nextTime) && !_isSameMinute(now, nextTime)) {
        // Vehicle is between previous and this stop
        return (i - 1, false);
      }
    }

    // If all stops are in the past, vehicle has completed the journey
    return (allStops.length, false);
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0x1A000000),
      highlightColor: const Color(0x0D000000),
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: [
            // Header skeleton
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
            // Timeline skeleton
            Padding(
              padding: const EdgeInsets.all(12),
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomAppBar(
              title: 'Connection Info',
              onBackButtonPressed: () => Navigator.of(context).pop(),
            ),

            Expanded(
              child: _isLoading
                  ? _buildLoadingSkeleton()
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              'Failed to load trip details',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0x80000000),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_tripDetails == null || _tripDetails!.legs.isEmpty) {
      return const Center(child: Text('No trip data available'));
    }

    // For now, we'll use the first leg (main transit leg)
    final leg = _tripDetails!.legs.first;
    final routeColor = _parseHexColor(leg.routeColor);
    final routeTextColor = leg.routeTextColor != null ? _parseHexColor(leg.routeTextColor) : AppColors.white;
    final modeIcon = getLegIcon(leg.mode);

    // Build complete list of stops
    final allStops = <TripPlace>[
      leg.from,
      ...leg.intermediateStops,
      leg.to,
    ];

    final (vehicleStopIndex, isVehicleAtStation) = _estimateVehiclePosition(allStops);
    final showVehicle = vehicleStopIndex >= 0 && vehicleStopIndex < allStops.length;

    // Create timeline items with vehicle position
    final timelineItems = <_TimelineItem>[];
    for (int i = 0; i < allStops.length; i++) {
      // Always add the station as a regular item
      timelineItems.add(_TimelineItem(stop: allStops[i], isVehicle: false));

      // Insert vehicle position marker between stops if vehicle is in transit
      if (showVehicle && !isVehicleAtStation && i == vehicleStopIndex && i < allStops.length - 1) {
        timelineItems.add(_TimelineItem(stop: null, isVehicle: true));
      }
    }

    // Determine upcoming stop (next stop the vehicle will reach)
    int upcomingStopIndex = -1;
    if (showVehicle) {
      if (isVehicleAtStation) {
        // If at a station, upcoming is the next station
        upcomingStopIndex = vehicleStopIndex < allStops.length - 1 ? vehicleStopIndex + 1 : -1;
      } else {
        // If between stations, upcoming is the next station after current segment
        upcomingStopIndex = vehicleStopIndex < allStops.length - 1 ? vehicleStopIndex + 1 : -1;
      }
    }

    final currentStopIndex = isVehicleAtStation ? vehicleStopIndex : vehicleStopIndex;

    // Collect all alerts
    final allAlerts = <String, Alert>{};
    for (final stop in allStops) {
      for (final alert in stop.alerts) {
        if (alert.headerText != null || alert.descriptionText != null) {
          final key = '${alert.headerText}|${alert.descriptionText}';
          allAlerts[key] = alert;
        }
      }
    }
    // Add leg-level alerts
    for (final alert in leg.alerts) {
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
          // Header card with route and destination
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
                          if (leg.displayName != null)
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
                                leg.displayName!,
                                style: TextStyle(
                                  color: routeTextColor,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          if (leg.headsign != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              '${getTransitModeName(leg.mode)} • ${leg.headsign!}',
                              style: const TextStyle(
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

          // Alerts section
          if (allAlerts.isNotEmpty) ...[
            const SizedBox(height: 12),
            CustomCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Text(
                        'Warnings',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ...allAlerts.values.map((alert) {
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
                            Icon(LucideIcons.triangleAlert, size: 16, color: Color(0xFFFFC107)),
                            const SizedBox(width: 4),
                            if (alert.headerText != null && alert.headerText!.isNotEmpty)
                              Text(
                                alert.headerText!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.black,
                                ),
                              ),
                            if (alert.descriptionText != null && alert.descriptionText!.isNotEmpty) ...[
                              if (alert.headerText != null) const SizedBox(height: 4),
                              Text(
                                alert.descriptionText!,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.black.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],

          // Information section
          const SizedBox(height: 12),
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
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
                    if (leg.realTime)
                      _buildInfoChip(
                        LucideIcons.radio,
                        'Real-time',
                        color: const Color(0xFF4CAF50),
                      ),
                    if (leg.cancelled == true)
                      _buildInfoChip(
                        LucideIcons.x,
                        'CANCELLED',
                        color: const Color(0xFFD32F2F),
                      ),
                    _buildInfoChip(
                      LucideIcons.clock,
                      formatDuration(leg.duration),
                    ),
                    if (leg.distance != null)
                      _buildInfoChip(
                        LucideIcons.ruler,
                        '${(leg.distance! / 1000).toStringAsFixed(1)} km',
                      ),
                    if (leg.agencyName != null)
                      _buildInfoChip(LucideIcons.building, leg.agencyName!),
                    if (leg.routeLongName != null && leg.routeLongName!.isNotEmpty)
                      _buildInfoChip(LucideIcons.route, leg.routeLongName!),
                  ],
                ),
              ],
            ),
          ),

          // Timeline section
          const SizedBox(height: 12),
          CustomCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Journey',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 16),
                FixedTimeline.tileBuilder(
                  theme: TimelineThemeData(
                    nodePosition: 0.08, // Offset from left edge to center vehicle icon
                    color: routeColor,
                    indicatorTheme: const IndicatorThemeData(
                      size: 28,
                    ),
                    connectorTheme: const ConnectorThemeData(
                      thickness: 2.5,
                    ),
                  ),
                  builder: TimelineTileBuilder.connected(
                    itemCount: timelineItems.length,
                    connectionDirection: ConnectionDirection.before,
                    contentsBuilder: (context, index) {
                      final item = timelineItems[index];

                      // Vehicle position indicator between stations - no content
                      if (item.isVehicle && item.stop == null) {
                        return const SizedBox.shrink();
                      }

                      final stop = item.stop!;
                      final stopIndex = allStops.indexOf(stop);
                      final isPassed = stopIndex <= currentStopIndex;
                      final isUpcoming = stopIndex == upcomingStopIndex;

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
                                      fontWeight: stopIndex == 0 ||
                                                 stopIndex == allStops.length - 1 ||
                                                 isUpcoming
                                          ? FontWeight.w600
                                          : FontWeight.normal,
                                      color: isPassed
                                          ? AppColors.black.withValues(alpha: 0.5)
                                          : AppColors.black,
                                    ),
                                  ),
                                ),
                                if (isUpcoming) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: routeColor.withValues(alpha: 0.2),
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
                            if (stop.departure != null || stop.arrival != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Arr: ${_formatTime(stop.arrival)}  Dep: ${_formatTime(stop.departure)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isPassed
                                      ? AppColors.black.withValues(alpha: 0.4)
                                      : AppColors.black.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                            if (stop.track != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Track ${stop.track}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isPassed
                                      ? AppColors.black.withValues(alpha: 0.4)
                                      : AppColors.black.withValues(alpha: 0.5),
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

                      // Vehicle position indicator between stations
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

                      // Regular station indicator
                      final stop = item.stop!;
                      final stopIndex = allStops.indexOf(stop);
                      final isPassed = stopIndex <= currentStopIndex;

                      // Determine the base indicator size and color
                      final bool isTerminal = stopIndex == 0 || stopIndex == allStops.length - 1;
                      final double dotSize = isTerminal ? 16 : 12;
                      final Color dotColor = isPassed
                          ? routeColor.withValues(alpha: 0.6)
                          : routeColor;

                      // Check if vehicle is at this specific station
                      final bool isVehicleHere = showVehicle && isVehicleAtStation && stopIndex == vehicleStopIndex;
                      final bool isFirstStop = stopIndex == 0;
                      final bool isLastStop  = stopIndex == allStops.length - 1;

                      // If vehicle is at this station, overlay the vehicle icon on top of the dot
                      if (isVehicleHere) {
                        return _IndicatorBox(
                          lineColor: dotColor,
                          // Hide the line entirely behind the 28×28 vehicle disc
                          centerGap: 28.0,
                          cutTop: isFirstStop,
                          cutBottom: isLastStop,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Base station dot still drawn for consistency
                              DotIndicator(
                                color: dotColor,
                                size: dotSize,
                              ),
                              // Vehicle icon overlaid on top
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

                      // Regular station dot without vehicle (fixed layout box, with bridge line)
                      return _IndicatorBox(
                        lineColor: dotColor,
                        // leave a small padding so the stroke doesn't peek out
                        centerGap: (dotSize),
                        cutTop: isFirstStop,
                        cutBottom: isLastStop,
                        child: Center(
                          child: DotIndicator(
                            color: dotColor,
                            size: dotSize,
                          ),
                        ),
                      );
                    },
                    connectorBuilder: (context, index, connectorType) {
                      // Determine if this connector segment is passed
                      bool isPassed = false;
                      if (index < timelineItems.length) {
                        final item = timelineItems[index];
                        if (item.isVehicle) {
                          // Segment before vehicle is passed
                          isPassed = true;
                        } else {
                          final stopIndex = allStops.indexOf(item.stop!);
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
        ],
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, {Color? color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (color ?? AppColors.black).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color ?? AppColors.black.withValues(alpha: 0.6)),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color ?? AppColors.black.withValues(alpha: 0.8),
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for timeline items
class _TimelineItem {
  final TripPlace? stop;
  final bool isVehicle;

  _TimelineItem({
    this.stop,
    required this.isVehicle,
  });
}

/// Wraps each indicator in a fixed 28×28 box and draws a short
/// vertical line behind it so the connector visually continues
/// through the node even when the visible dot is smaller.
class _IndicatorBox extends StatelessWidget {
  final Widget child;
  final Color lineColor;
  final double centerGap;
  final bool cutTop;
  final bool cutBottom;
  const _IndicatorBox({
    required this.child,
    required this.lineColor,
    this.centerGap = 0.0,
    this.cutTop = false,
    this.cutBottom = false,
  });

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
          // top segment
          if (!cutTop && sideLen > 0)
            Positioned(
              top: 0,
              child: SizedBox(
                width: 2.5,
                height: sideLen,
                child:
                    DecoratedBox(decoration: BoxDecoration(color: lineColor)),
              ),
            ),
          // bottom segment
          if (!cutBottom && sideLen > 0)
            Positioned(
              bottom: 0,
              child: SizedBox(
                width: 2.5,
                height: sideLen,
                child:
                    DecoratedBox(decoration: BoxDecoration(color: lineColor)),
              ),
            ),
          child,
        ],
      ),
    );
  }
}