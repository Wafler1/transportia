import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:timelines_plus/timelines_plus.dart';

import '../models/itinerary.dart';
import '../models/journey_stop.dart';
import '../providers/theme_provider.dart';
import '../services/trip_details_service.dart';
import '../theme/app_colors.dart';
import '../utils/color_utils.dart';
import '../utils/custom_page_route.dart';
import '../utils/duration_formatter.dart';
import '../utils/leg_helper.dart' show getLegIcon, getTransitModeName;
import '../utils/journey_utils.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/info_chip.dart';
import '../widgets/skeletons/skeleton_card.dart';
import '../widgets/skeletons/skeleton_shimmer.dart';
import '../widgets/stop_schedule_row.dart';
import '../widgets/timeline_indicator_box.dart';
import 'itinerary_map_screen.dart';

class ConnectionInfoScreen extends StatefulWidget {
  final String tripId;

  const ConnectionInfoScreen({super.key, required this.tripId});

  @override
  State<ConnectionInfoScreen> createState() => _ConnectionInfoScreenState();
}

class _ConnectionInfoScreenState extends State<ConnectionInfoScreen> {
  Itinerary? _itinerary;
  bool _isLoading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _fetchTripDetails();
    // Start periodic refresh every 5 seconds to update vehicle position
    _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _itinerary != null) {
        setState(() {
          // This will trigger a rebuild and recalculate the vehicle position
        });
      }
    });
  }

  Future<void> _fetchTripDetails() async {
    try {
      final details = await TripDetailsService.fetchTripDetails(
        tripId: widget.tripId,
      );
      if (mounted) {
        setState(() {
          _itinerary = details;
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
  (int, bool) _estimateVehiclePosition(List<JourneyStop> stops) {
    final now = DateTime.now();

    // Check if trip hasn't started yet
    final firstStop = stops.first;
    final firstDeparture = firstStop.departure ?? firstStop.arrival;
    if (firstDeparture != null &&
        !_isSameMinute(now, firstDeparture) &&
        now.isBefore(firstDeparture)) {
      return (-1, false); // Trip hasn't started, don't show vehicle
    }

    // Check if trip has ended
    final lastStop = stops.last;
    final lastArrival = lastStop.arrival ?? lastStop.departure;
    if (lastArrival != null &&
        !_isSameMinute(now, lastArrival) &&
        now.isAfter(lastArrival)) {
      return (stops.length, false); // Trip has ended, don't show vehicle
    }

    for (int i = 0; i < stops.length; i++) {
      final stop = stops[i];
      final arrival = stop.arrival;
      final departure = stop.departure;

      // Check if vehicle is at this station
      // Vehicle is at station if:
      // 1. Current time is in the same minute as departure time (vehicle hasn't left yet)
      // 2. OR current time is between arrival and departure
      if (departure != null && _isSameMinute(now, departure)) {
        return (
          i,
          true,
        ); // At this station (current time matches departure minute)
      }

      if (arrival != null && departure != null) {
        if (now.isAfter(arrival) && now.isBefore(departure)) {
          return (i, true); // At this station (between arrival and departure)
        }
      }

      // Check if vehicle hasn't reached this stop yet
      final nextTime = departure ?? arrival;
      if (nextTime != null &&
          now.isBefore(nextTime) &&
          !_isSameMinute(now, nextTime)) {
        // Vehicle is between previous and this stop
        return (i - 1, false);
      }
    }

    // If all stops are in the past, vehicle has completed the journey
    return (stops.length, false);
  }

  Widget _buildLoadingSkeleton() {
    return SkeletonShimmer(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          children: const [
            // Header skeleton
            SkeletonCard(
              height: 120,
              borderRadius: BorderRadius.all(Radius.circular(14)),
              margin: EdgeInsets.all(12),
            ),
            // Timeline skeleton
            SkeletonCard(
              height: 400,
              borderRadius: BorderRadius.all(Radius.circular(14)),
              margin: EdgeInsets.all(12),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
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
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.black.withValues(alpha: 0.5),
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
    if (_itinerary == null || _itinerary!.legs.isEmpty) {
      return Center(
        child: EmptyState(
          title: 'No trip data available',
          titleStyle: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppColors.black.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    // For now, we'll use the first leg (main transit leg)
    final leg = _itinerary!.legs.first;
    final routeColor =
        parseHexColor(leg.routeColor) ?? AppColors.accentOf(context);
    final routeTextColor =
        parseHexColor(leg.routeTextColor) ?? AppColors.solidWhite;
    final modeIcon = getLegIcon(leg.mode);

    final stops = buildJourneyStops(leg);

    final (vehicleStopIndex, isVehicleAtStation) = _estimateVehiclePosition(
      stops,
    );
    final showVehicle =
        vehicleStopIndex >= 0 && vehicleStopIndex < stops.length;

    // Create timeline items with vehicle position
    final timelineItems = <_TimelineItem>[];
    for (int i = 0; i < stops.length; i++) {
      // Always add the station as a regular item
      timelineItems.add(_TimelineItem(stop: stops[i], isVehicle: false));

      // Insert vehicle position marker between stops if vehicle is in transit
      if (showVehicle &&
          !isVehicleAtStation &&
          i == vehicleStopIndex &&
          i < stops.length - 1) {
        timelineItems.add(_TimelineItem(stop: null, isVehicle: true));
      }
    }

    // Determine upcoming stop (next stop the vehicle will reach)
    int upcomingStopIndex = -1;
    if (showVehicle) {
      if (isVehicleAtStation) {
        // If at a station, upcoming is the next station
        upcomingStopIndex = vehicleStopIndex < stops.length - 1
            ? vehicleStopIndex + 1
            : -1;
      } else {
        // If between stations, upcoming is the next station after current segment
        upcomingStopIndex = vehicleStopIndex < stops.length - 1
            ? vehicleStopIndex + 1
            : -1;
      }
    }

    final currentStopIndex = vehicleStopIndex;

    // Collect all alerts
    final allAlerts = <String, Alert>{};
    for (final stop in stops) {
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
                    Icon(modeIcon, size: 32, color: AppColors.black),
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
                    // Map icon button
                    GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          CustomPageRoute(
                            child: ItineraryMapScreen(
                              itinerary: _itinerary!,
                              showCarousel: false,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          LucideIcons.map,
                          size: 20,
                          color: AppColors.accentOf(context),
                        ),
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
                  Row(
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

          // Information section
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
                    if (leg.realTime)
                      const InfoChip(
                        icon: LucideIcons.radio,
                        label: 'Real-time',
                      ),
                    if (leg.cancelled == true)
                      const InfoChip(
                        icon: LucideIcons.x,
                        label: 'CANCELLED',
                        tint: Color(0xFFD32F2F),
                      ),
                    InfoChip(
                      icon: LucideIcons.clock,
                      label: formatDuration(leg.duration),
                    ),
                    if (leg.distance != null)
                      InfoChip(
                        icon: LucideIcons.ruler,
                        label:
                            '${(leg.distance! / 1000).toStringAsFixed(1)} km',
                      ),
                    if (leg.agencyName != null)
                      InfoChip(
                        icon: LucideIcons.building,
                        label: leg.agencyName!,
                      ),
                    if (leg.routeLongName != null &&
                        leg.routeLongName!.isNotEmpty)
                      InfoChip(
                        icon: LucideIcons.route,
                        label: leg.routeLongName!,
                      ),
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
                Text(
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
                    nodePosition:
                        0.08, // Offset from left edge to center vehicle icon
                    color: routeColor,
                    indicatorTheme: const IndicatorThemeData(size: 28),
                    connectorTheme: const ConnectorThemeData(thickness: 2.5),
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
                      final stopIndex = stops.indexOf(stop);
                      final isPassed = stopIndex <= currentStopIndex;
                      final isUpcoming = stopIndex == upcomingStopIndex;

                      final arrRow = buildStopScheduleRow(
                        'Arr',
                        stop.scheduledArrival,
                        stop.arrival,
                        isPassed,
                      );
                      final depRow = buildStopScheduleRow(
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
                                              stopIndex == stops.length - 1 ||
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
                            if (arrRow != null || depRow != null) ...[
                              const SizedBox(height: 2),
                              if (arrRow != null) arrRow,
                              if (depRow != null) ...[
                                if (arrRow != null) const SizedBox(height: 2),
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
                        return TimelineIndicatorBox(
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
                      final stopIndex = stops.indexOf(stop);
                      final isPassed = stopIndex <= currentStopIndex;

                      // Determine the base indicator size and color
                      final bool isTerminal =
                          stopIndex == 0 || stopIndex == stops.length - 1;
                      final double dotSize = isTerminal ? 16 : 12;
                      final Color dotColor = isPassed
                          ? routeColor.withValues(alpha: 0.6)
                          : routeColor;

                      // Check if vehicle is at this specific station
                      final bool isVehicleHere =
                          showVehicle &&
                          isVehicleAtStation &&
                          stopIndex == vehicleStopIndex;
                      final bool isFirstStop = stopIndex == 0;
                      final bool isLastStop = stopIndex == stops.length - 1;

                      // If vehicle is at this station, overlay the vehicle icon on top of the dot
                      if (isVehicleHere) {
                        return TimelineIndicatorBox(
                          lineColor: dotColor,
                          // Hide the line entirely behind the 28×28 vehicle disc
                          centerGap: 28.0,
                          cutTop: isFirstStop,
                          cutBottom: isLastStop,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Base station dot still drawn for consistency
                              DotIndicator(color: dotColor, size: dotSize),
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
                      return TimelineIndicatorBox(
                        lineColor: dotColor,
                        // leave a small padding so the stroke doesn't peek out
                        centerGap: (dotSize),
                        cutTop: isFirstStop,
                        cutBottom: isLastStop,
                        child: Center(
                          child: DotIndicator(color: dotColor, size: dotSize),
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
        ],
      ),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

// Helper class for timeline items
class _TimelineItem {
  final JourneyStop? stop;
  final bool isVehicle;

  _TimelineItem({this.stop, required this.isVehicle});
}
