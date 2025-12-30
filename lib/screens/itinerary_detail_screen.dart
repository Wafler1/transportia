import 'dart:convert';

import 'package:transportia/widgets/load_more_button.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:timelines_plus/timelines_plus.dart';

import '../models/itinerary.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../utils/color_utils.dart';
import '../utils/custom_page_route.dart';
import '../utils/duration_formatter.dart';
import '../utils/itinerary_leg_utils.dart';
import '../utils/leg_helper.dart';
import '../utils/time_utils.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_card.dart';
import '../widgets/info_chip.dart';
import 'itinerary_map_screen.dart';

class ItineraryDetailScreen extends StatefulWidget {
  final Itinerary itinerary;

  const ItineraryDetailScreen({super.key, required this.itinerary});

  @override
  State<ItineraryDetailScreen> createState() => _ItineraryDetailScreenState();
}

class _ItineraryDetailScreenState extends State<ItineraryDetailScreen> {
  bool _isSharing = false;

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final displayLegs = buildDisplayLegs(widget.itinerary.legs);

    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CustomAppBar(
              title: 'Itinerary Details',
              onBackButtonPressed: () => Navigator.of(context).pop(),
            ),
            JourneyOverviewWidget(itinerary: widget.itinerary),
            Expanded(
              child: displayLegs.isEmpty
                  ? Center(
                      child: Text(
                        'No additional steps required for this journey.',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.black.withValues(alpha: 0.4),
                        ),
                      ),
                    )
                  : Builder(
                      builder: (context) {
                        final hasFinishCard = widget.itinerary.legs.isNotEmpty;
                        final finishInsertIndex = displayLegs.length;
                        final shareIndex =
                            finishInsertIndex + (hasFinishCard ? 1 : 0);
                        final totalItems = shareIndex + 1;

                        return ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: totalItems,
                          itemBuilder: (context, index) {
                            if (index < displayLegs.length) {
                              final entry = displayLegs[index];
                              if (entry.isTransfer) {
                                return TransferLegCard(leg: entry.leg);
                              }
                              return LegDetailsWidget(leg: entry.leg);
                            }

                            if (hasFinishCard && index == finishInsertIndex) {
                              final finishLeg = widget.itinerary.legs.last;
                              return FinishLegCard(
                                leg: finishLeg,
                                arrivalTime: widget.itinerary.endTime,
                                totalDuration: widget.itinerary.duration,
                              );
                            }

                            if (index == shareIndex) {
                              return LoadMoreButton(
                                onTap: _shareItinerary,
                                isLoading: _isSharing,
                                label: 'Share this trip',
                                icon: LucideIcons.share2,
                              );
                            }

                            return const SizedBox.shrink();
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareItinerary() async {
    if (_isSharing) return;

    final legs = widget.itinerary.legs;
    if (legs.isEmpty) {
      debugPrint('Cannot share itinerary without any legs.');
      return;
    }

    setState(() => _isSharing = true);

    try {
      final firstLeg = legs.first;
      final lastLeg = legs.last;

      final payload = jsonEncode({
        'from': {'lat': firstLeg.fromLat, 'lon': firstLeg.fromLon},
        'to': {'lat': lastLeg.toLat, 'lon': lastLeg.toLon},
        'time': widget.itinerary.startTime.toIso8601String(),
      });

      final encoded = base64Url.encode(utf8.encode(payload));
      final shareUrl = 'https://link.entaria.net/trip/$encoded';

      await Share.share(shareUrl);
    } catch (error, stackTrace) {
      debugPrint('Failed to share itinerary: $error');
      debugPrint('$stackTrace');
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }
}

class JourneyOverviewWidget extends StatelessWidget {
  final Itinerary itinerary;

  const JourneyOverviewWidget({super.key, required this.itinerary});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main journey info row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Departure
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Departure',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatTime(itinerary.startTime),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
              ),
              // Duration
              Expanded(
                child: Column(
                  children: [
                    const Icon(LucideIcons.clock, size: 20),
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
              // Arrival
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Arrival',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.black.withValues(alpha: 0.5),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatTime(itinerary.endTime),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Additional stats row with map icon on the right
          Row(
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  _buildStatChip(
                    LucideIcons.repeat,
                    '${itinerary.transfers}',
                    itinerary.transfers == 1 ? 'transfer' : 'transfers',
                  ),
                  // Only show calories if there is walking in the itinerary
                  if (itinerary.walkingDistance > 0)
                    _buildStatChip(
                      LucideIcons.flame,
                      '${itinerary.calories}',
                      'cal',
                    ),
                  // Show cost if fare information is available
                  if (itinerary.fare != null && itinerary.fare!.amount > 0)
                    _buildStatChip(
                      LucideIcons.banknote,
                      '${itinerary.fare!.amount.toStringAsFixed(2)}',
                      itinerary.fare!.currency,
                    ),
                  // Show alerts if there are any
                  if (itinerary.alertsCount > 0)
                    _buildStatChip(
                      LucideIcons.triangleAlert,
                      '${itinerary.alertsCount}',
                      itinerary.alertsCount == 1 ? 'alert' : 'alerts',
                    ),
                ],
              ),
              const Spacer(),
              // Map icon button
              GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    CustomPageRoute(
                      child: ItineraryMapScreen(itinerary: itinerary),
                    ),
                  );
                },
                child: Icon(
                  LucideIcons.map,
                  size: 20,
                  color: AppColors.accentOf(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.black.withValues(alpha: 0.6)),
        const SizedBox(width: 4),
        Text(
          '$value $label',
          style: TextStyle(
            fontSize: 14,
            color: AppColors.black.withValues(alpha: 0.8),
          ),
        ),
      ],
    );
  }
}

class LegDetailsWidget extends StatefulWidget {
  final Leg leg;

  const LegDetailsWidget({super.key, required this.leg});

  @override
  State<LegDetailsWidget> createState() => _LegDetailsWidgetState();
}

class _LegDetailsWidgetState extends State<LegDetailsWidget> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final isWalkLeg = widget.leg.mode == 'WALK';
    final scheduledStart =
        widget.leg.scheduledStartTime ?? widget.leg.startTime;
    final scheduledEnd = widget.leg.scheduledEndTime ?? widget.leg.endTime;
    final departureDelay = _departureDelay;
    final arrivalDelay = _arrivalDelay;

    return GestureDetector(
      onTap: isWalkLeg
          ? null
          : () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
      child: CustomCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main leg info (always visible)
            Row(
              children: [
                _buildLegIcon(),
                const SizedBox(width: 8),
                // Title with optional route colour styling
                Expanded(child: _buildTitleWidget()),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.leg.alerts.isNotEmpty)
                      const Padding(
                        padding: EdgeInsets.only(right: 4),
                        child: Icon(
                          LucideIcons.triangleAlert,
                          size: 16,
                          color: Color(0xFFFF8A00),
                        ),
                      ),
                    Text(
                      formatDuration(widget.leg.duration),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                  ],
                ),
                if (!isWalkLeg) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded
                        ? LucideIcons.chevronUp
                        : LucideIcons.chevronDown,
                    size: 16,
                    color: AppColors.accentOf(context),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _buildModeText(),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),

            // Origin and destination (only show when collapsed)
            if (!_isExpanded) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(LucideIcons.arrowRight, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${formatTime(scheduledStart)} - ${widget.leg.fromName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.black.withValues(alpha: 0.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (departureDelay != null)
                    _DelayChip(label: formatDelay(departureDelay)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(LucideIcons.arrowDown, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${formatTime(scheduledEnd)} - ${widget.leg.toName}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.black.withValues(alpha: 0.5),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  if (arrivalDelay != null)
                    _DelayChip(label: formatDelay(arrivalDelay)),
                ],
              ),
            ],

            // Expanded content (only for non-walk legs)
            if (_isExpanded && !isWalkLeg) ...[
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: SizedBox(
                  height: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: Color(0x33000000)),
                  ),
                ),
              ),
              _buildTransitTimelineContent(),
            ],
          ],
        ),
      ),
    );
  }

  String _buildModeText() {
    final modeName = getTransitModeName(widget.leg.mode);

    if (widget.leg.mode == 'WALK') {
      // For walk legs, add distance in parentheses
      final distance = widget.leg.distance;
      if (distance != null && distance > 0) {
        return '$modeName (${(distance / 1000).toStringAsFixed(2)} km)';
      }
      return modeName;
    } else {
      // For transit legs, add headsign if available
      if (widget.leg.headsign != null && widget.leg.headsign!.isNotEmpty) {
        return '$modeName • ${widget.leg.headsign}';
      }
      return modeName;
    }
  }

  Widget _buildTransitTimelineContent() {
    // Build a list of all stops including origin and destination
    final stops = <_TimelineStop>[];

    // Add origin
    stops.add(
      _TimelineStop(
        name: widget.leg.fromName,
        time: widget.leg.startTime,
        track: widget.leg.fromTrack,
        scheduledTime: widget.leg.scheduledStartTime,
        cancelled: widget.leg.cancelled,
        isFirst: true,
        isLast: false,
      ),
    );

    // Add intermediate stops
    for (final stop in widget.leg.intermediateStops) {
      stops.add(
        _TimelineStop(
          name: stop.name,
          time: stop.arrival ?? stop.departure,
          track: stop.track,
          scheduledTime: stop.scheduledArrival ?? stop.scheduledDeparture,
          cancelled: stop.cancelled,
          isFirst: false,
          isLast: false,
        ),
      );
    }

    // Add destination
    stops.add(
      _TimelineStop(
        name: widget.leg.toName,
        time: widget.leg.endTime,
        track: widget.leg.toTrack,
        scheduledTime: widget.leg.scheduledEndTime,
        cancelled: widget.leg.cancelled,
        isFirst: false,
        isLast: true,
      ),
    );

    final routeColor =
        parseHexColor(widget.leg.routeColor) ?? AppColors.accentOf(context);
    final fadedRouteColor = routeColor.withValues(alpha: 0.6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Alerts
        if (widget.leg.alerts.isNotEmpty) ...[
          const SizedBox(height: 6),
          ...widget.leg.alerts.map((alert) => _buildAlertWidget(alert)),
          const SizedBox(height: 6),
        ],

        // Timeline
        FixedTimeline.tileBuilder(
          theme: TimelineThemeData(
            nodePosition: 0,
            color: routeColor,
            indicatorTheme: const IndicatorThemeData(size: 16),
            connectorTheme: const ConnectorThemeData(thickness: 2.5),
          ),
          builder: TimelineTileBuilder.connected(
            itemCount: stops.length,
            connectionDirection: ConnectionDirection.before,
            contentsBuilder: (context, index) {
              final stop = stops[index];
              return Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 16),
                child: _buildStopInfo(stop),
              );
            },
            indicatorBuilder: (context, index) {
              final stop = stops[index];
              if (stop.isFirst || stop.isLast) {
                return DotIndicator(color: routeColor, size: 16);
              }
              return DotIndicator(color: fadedRouteColor, size: 12);
            },
            connectorBuilder: (context, index, connectorType) {
              return SolidLineConnector(color: fadedRouteColor);
            },
          ),
        ),

        const SizedBox(height: 12),

        // Metadata section
        _buildMetadataSection(),
      ],
    );
  }

  Widget _buildMetadataSection() {
    final metadata = <Widget>[];
    final departureDelay = _departureDelay;
    final arrivalDelay = _arrivalDelay;

    // Cancelled
    if (widget.leg.cancelled) {
      metadata.add(
        InfoChip(
          icon: LucideIcons.circleAlert,
          label: 'CANCELLED',
          tint: const Color(0xFFD32F2F),
        ),
      );
    }

    // Track info integrated here
    if (widget.leg.fromTrack != null) {
      metadata.add(
        InfoChip(
          icon: LucideIcons.trainTrack,
          label: 'Track ${widget.leg.fromTrack}',
        ),
      );
    }

    // Real-time indicator
    if (widget.leg.realTime) {
      metadata.add(const InfoChip(icon: LucideIcons.radio, label: 'Real-time'));
    }

    // Distance
    if (widget.leg.distance != null && widget.leg.distance! > 0) {
      metadata.add(
        InfoChip(
          icon: LucideIcons.ruler,
          label: '${(widget.leg.distance! / 1000).toStringAsFixed(2)} km',
        ),
      );
    }

    // Agency and Route
    if (widget.leg.agencyName != null) {
      metadata.add(
        InfoChip(icon: LucideIcons.building, label: widget.leg.agencyName!),
      );
    }

    if (widget.leg.routeLongName != null &&
        widget.leg.routeLongName!.isNotEmpty) {
      metadata.add(
        InfoChip(icon: LucideIcons.route, label: widget.leg.routeLongName!),
      );
    }

    final hasDelay =
        (departureDelay != null && !departureDelay.isNegative) ||
        (arrivalDelay != null && !arrivalDelay.isNegative);
    final hasAhead =
        (departureDelay != null && departureDelay.isNegative) ||
        (arrivalDelay != null && arrivalDelay.isNegative);

    if (hasDelay) {
      metadata.add(
        const InfoChip(
          icon: LucideIcons.circleAlert,
          label: 'Delayed',
          tint: Color(0xFFB26A00),
        ),
      );
    }

    if (!hasDelay && hasAhead) {
      metadata.add(
        const InfoChip(
          icon: LucideIcons.check,
          label: 'Ahead',
          tint: Color(0xFF2E7D32),
        ),
      );
    }

    if (widget.leg.interlineWithPreviousLeg) {
      metadata.add(const InfoChip(icon: LucideIcons.link, label: 'Interlined'));
    }

    if (metadata.isEmpty) return const SizedBox.shrink();

    return Wrap(spacing: 8, runSpacing: 8, children: metadata);
  }

  Widget _buildStopInfo(_TimelineStop stop) {
    final scheduledTime = stop.scheduledTime ?? stop.time;
    final actualTime = stop.time;
    final delay = (scheduledTime != null && actualTime != null)
        ? computeDelay(scheduledTime, actualTime)
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stop.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: stop.isFirst || stop.isLast
                ? FontWeight.w600
                : FontWeight.normal,
            color: AppColors.black,
          ),
        ),
        if (scheduledTime != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Text(
                formatTime(scheduledTime),
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
              if (delay != null) ...[
                const SizedBox(width: 6),
                Text(
                  formatDelay(delay),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _delayColor(delay),
                  ),
                ),
              ],
            ],
          ),
        ],
        if (stop.track != null && !stop.isFirst) ...[
          const SizedBox(height: 2),
          Text(
            'Track ${stop.track}',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.black.withValues(alpha: 0.5),
            ),
          ),
        ],
        if (stop.cancelled) ...[
          const SizedBox(height: 2),
          Text(
            'CANCELLED',
            style: TextStyle(
              fontSize: 12,
              color: const Color(0xFFD32F2F),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAlertWidget(Alert alert) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3CD),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFFFC107)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            LucideIcons.triangleAlert,
            size: 16,
            color: const Color(0xFFF57C00),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (alert.headerText != null && alert.headerText!.isNotEmpty)
                  Text(
                    alert.headerText!,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.solidBlack,
                    ),
                  ),
                if (alert.descriptionText != null &&
                    alert.descriptionText!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    alert.descriptionText!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.solidBlack.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Duration? get _departureDelay =>
      computeDelay(widget.leg.scheduledStartTime, widget.leg.startTime);

  Duration? get _arrivalDelay =>
      computeDelay(widget.leg.scheduledEndTime, widget.leg.endTime);

  Color _delayColor(Duration delay) =>
      delay.isNegative ? const Color(0xFF2E7D32) : const Color(0xFFB26A00);

  Widget _buildLegIcon() {
    return Icon(getLegIcon(widget.leg.mode), size: 24, color: AppColors.black);
  }

  // Build the title widget, applying background and text colours if provided.
  Widget _buildTitleWidget() {
    if (widget.leg.displayName != null) {
      final bg = parseHexColor(widget.leg.routeColor);
      final txt = parseHexColor(widget.leg.routeTextColor) ?? AppColors.black;
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg ?? const Color(0x00000000),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.leg.displayName!.length > 0
                ? widget.leg.displayName!
                : getTransitModeName(widget.leg.mode),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: txt,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      );
    }
    // Fallback to transit mode name when no short name.
    return Text(
      getTransitModeName(widget.leg.mode),
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.black,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }
}

class TransferLegCard extends StatelessWidget {
  final Leg leg;

  const TransferLegCard({super.key, required this.leg});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.arrowLeftRight, size: 20),
              const SizedBox(width: 8),
              Text(
                'Transfer',
                style: TextStyle(
                  fontSize: 16,
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
                child: Text(
                  '${formatTime(leg.startTime)} - ${leg.fromName}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.black.withValues(alpha: 0.5),
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          if (leg.distance != null && leg.distance! > 0) ...[
            const SizedBox(height: 4),
            Text(
              'Approx. ${(leg.distance! / 1000).toStringAsFixed(2)} km walk',
              style: TextStyle(
                fontSize: 13,
                color: AppColors.black.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _DelayChip extends StatelessWidget {
  const _DelayChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final isAhead = label.startsWith('-');
    final color = isAhead ? const Color(0xFF2E7D32) : const Color(0xFFB26A00);
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isAhead ? const Color(0xFFE8F5E9) : const Color(0xFFFFF1E0),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class FinishLegCard extends StatelessWidget {
  final Leg leg;
  final DateTime arrivalTime;
  final int totalDuration;

  const FinishLegCard({
    super.key,
    required this.leg,
    required this.arrivalTime,
    required this.totalDuration,
  });

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(LucideIcons.flag, size: 20),
              const SizedBox(width: 8),
              Text(
                'Finish',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
              ),
              const Spacer(),
              Text(
                formatTime(arrivalTime),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineStop {
  final String name;
  final DateTime? time;
  final String? track;
  final DateTime? scheduledTime;
  final bool cancelled;
  final bool isFirst;
  final bool isLast;

  _TimelineStop({
    required this.name,
    this.time,
    this.track,
    this.scheduledTime,
    this.cancelled = false,
    this.isFirst = false,
    this.isLast = false,
  });
}
