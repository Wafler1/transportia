import 'package:entaria_app/utils/leg_helper.dart';

import '../utils/duration_formatter.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:timelines_plus/timelines_plus.dart';
import '../models/itinerary.dart';
import '../theme/app_colors.dart';
import '../utils/custom_page_route.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_card.dart';
import 'itinerary_map_screen.dart';

class ItineraryDetailScreen extends StatelessWidget {
  final Itinerary itinerary;

  const ItineraryDetailScreen({super.key, required this.itinerary});

  @override
  Widget build(BuildContext context) {
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
            JourneyOverviewWidget(itinerary: itinerary),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.only(bottom: 16),
                itemCount: itinerary.legs.length,
                itemBuilder: (context, index) {
                  final leg = itinerary.legs[index];
                  return LegDetailsWidget(leg: leg);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class JourneyOverviewWidget extends StatelessWidget {
  final Itinerary itinerary;

  const JourneyOverviewWidget({super.key, required this.itinerary});


  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    return '${localTime.hour}:${localTime.minute.toString().padLeft(2, '0')}';
  }

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
                      _formatTime(itinerary.startTime),
                      style: const TextStyle(
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
                      style: const TextStyle(
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
                      _formatTime(itinerary.endTime),
                      style: const TextStyle(
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
                  Navigator.of(context).push(CustomPageRoute(
                    child: ItineraryMapScreen(itinerary: itinerary),
                  ));
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

    return GestureDetector(
      onTap: isWalkLeg ? null : () {
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
                Expanded(
                  child: _buildTitleWidget(),
                ),
                const SizedBox(width: 8),
                Text(
                  formatDuration(widget.leg.duration),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
                if (!isWalkLeg) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? LucideIcons.chevronUp : LucideIcons.chevronDown,
                    size: 16,
                    color: AppColors.accentOf(context),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _buildModeText(),
              style: const TextStyle(
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
                      '${_formatTime(widget.leg.startTime)} - ${widget.leg.fromName}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0x80000000),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(LucideIcons.arrowDown, size: 16),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${_formatTime(widget.leg.endTime)} - ${widget.leg.toName}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0x80000000),
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
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
    stops.add(_TimelineStop(
      name: widget.leg.fromName,
      time: widget.leg.startTime,
      track: widget.leg.fromTrack,
      scheduledTime: widget.leg.scheduledStartTime,
      cancelled: widget.leg.cancelled,
      isFirst: true,
      isLast: false,
    ));

    // Add intermediate stops
    for (final stop in widget.leg.intermediateStops) {
      stops.add(_TimelineStop(
        name: stop.name,
        time: stop.arrival ?? stop.departure,
        track: stop.track,
        scheduledTime: stop.scheduledArrival ?? stop.scheduledDeparture,
        cancelled: stop.cancelled,
        isFirst: false,
        isLast: false,
      ));
    }

    // Add destination
    stops.add(_TimelineStop(
      name: widget.leg.toName,
      time: widget.leg.endTime,
      track: widget.leg.toTrack,
      scheduledTime: widget.leg.scheduledEndTime,
      cancelled: widget.leg.cancelled,
      isFirst: false,
      isLast: true,
    ));

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
            color: widget.leg.routeColor != null
                ? _parseHexColor(widget.leg.routeColor) ?? AppColors.accent
                : AppColors.accentOf(context),
            indicatorTheme: const IndicatorThemeData(
              size: 16,
            ),
            connectorTheme: const ConnectorThemeData(
              thickness: 2.5,
            ),
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
                return DotIndicator(
                  color: widget.leg.routeColor != null
                ? _parseHexColor(widget.leg.routeColor) ?? AppColors.accent
                : AppColors.accentOf(context),
                  size: 16
                );
              }
              return DotIndicator(
                color: widget.leg.routeColor != null
                ? _parseHexColor(widget.leg.routeColor)?.withValues(alpha: 0.6) ?? AppColors.accentOf(context).withValues(alpha: 0.6)
                : AppColors.accentOf(context).withValues(alpha: 0.6),
                size: 12,
              );
            },
            connectorBuilder: (context, index, connectorType) {
              return SolidLineConnector(
                color: widget.leg.routeColor != null
                ? _parseHexColor(widget.leg.routeColor)?.withValues(alpha: 0.6) ?? AppColors.accentOf(context).withValues(alpha: 0.6)
                : AppColors.accentOf(context).withValues(alpha: 0.6),
              );
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

    // Cancelled
    if (widget.leg.cancelled) {
      metadata.add(_buildInfoChip(LucideIcons.circleAlert, 'CANCELLED', color: const Color(0xFFD32F2F)));
    }

    // Track info integrated here
    if (widget.leg.fromTrack != null) {
      metadata.add(_buildInfoChip(LucideIcons.trainTrack, 'Track ${widget.leg.fromTrack}'));
    }

    // Real-time indicator
    if (widget.leg.realTime) {
      metadata.add(_buildInfoChip(LucideIcons.radio, 'Real-time'));
    }

    // Distance
    if (widget.leg.distance != null && widget.leg.distance! > 0) {
      metadata.add(_buildInfoChip(LucideIcons.ruler, '${(widget.leg.distance! / 1000).toStringAsFixed(2)} km'));
    }

    // Agency and Route
    if (widget.leg.agencyName != null) {
      metadata.add(_buildInfoChip(LucideIcons.building, widget.leg.agencyName!));
    }

    if (widget.leg.routeLongName != null && widget.leg.routeLongName!.isNotEmpty) {
      metadata.add(_buildInfoChip(LucideIcons.route, widget.leg.routeLongName!));
    }

    if (widget.leg.interlineWithPreviousLeg) {
      metadata.add(_buildInfoChip(LucideIcons.link, 'Interlined'));
    }

    if (metadata.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: metadata,
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

  Widget _buildStopInfo(_TimelineStop stop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          stop.name,
          style: TextStyle(
            fontSize: 14,
            fontWeight: stop.isFirst || stop.isLast ? FontWeight.w600 : FontWeight.normal,
            color: AppColors.black,
          ),
        ),
        if (stop.time != null) ...[
          const SizedBox(height: 2),
          Text(
            _formatTime(stop.time!),
            style: TextStyle(
              fontSize: 13,
              color: AppColors.black.withValues(alpha: 0.6),
            ),
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
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                if (alert.descriptionText != null && alert.descriptionText!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    alert.descriptionText!,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.black.withValues(alpha: 0.8),
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

  String _formatTime(DateTime time) {
    final localTime = time.toLocal();
    return '${localTime.hour}:${localTime.minute.toString().padLeft(2, '0')}';
  }

  Widget _buildLegIcon() {
    return Icon(getLegIcon(widget.leg.mode), size: 24, color: AppColors.black);
  }

  // Parse a hex colour string like "#FF0000" into a Flutter Color.
  Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    var cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) cleaned = 'FF' + cleaned;
    if (cleaned.length != 8) return null;
    return Color(int.parse('0x$cleaned'));
  }

  // Build the title widget, applying background and text colours if provided.
  Widget _buildTitleWidget() {
    if (widget.leg.displayName != null) {
      final bg = _parseHexColor(widget.leg.routeColor);
      final txt = _parseHexColor(widget.leg.routeTextColor) ?? AppColors.black;
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg ?? const Color(0x00000000),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            widget.leg.displayName!.length > 0 ? widget.leg.displayName! : getTransitModeName(widget.leg.mode),
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
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.black,
      ),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
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
