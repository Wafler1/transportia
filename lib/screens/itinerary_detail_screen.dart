import 'package:entaria_app/utils/leg_helper.dart';

import '../utils/duration_formatter.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/itinerary.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/custom_card.dart';

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

  // Calculate total walking duration in seconds
  int _calculateWalkingDuration() {
    int totalSeconds = 0;
    for (final leg in itinerary.legs) {
      if (leg.mode == 'WALK') {
        totalSeconds += leg.duration;
      }
    }
    return totalSeconds;
  }

  int _calculateCalories() {
    // Average: ~4.5 calories per minute of walking
    final walkingSeconds = _calculateWalkingDuration();
    final walkingMinutes = walkingSeconds / 60;
    return (walkingMinutes * 4.5).round();
  }

  String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
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
          // Additional stats row
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
              if (_calculateWalkingDuration() > 0)
                _buildStatChip(
                  LucideIcons.flame,
                  '${_calculateCalories()}',
                  'cal',
                ),
              // Show cost if fare information is available
              if (itinerary.fare != null && itinerary.fare!.amount > 0)
                _buildStatChip(
                  LucideIcons.banknote,
                  '${itinerary.fare!.amount.toStringAsFixed(2)}',
                  itinerary.fare!.currency,
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

class LegDetailsWidget extends StatelessWidget {
  final Leg leg;

  const LegDetailsWidget({super.key, required this.leg});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  formatDuration(leg.duration),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${getTransitModeName(leg.mode)}${leg.headsign != null && leg.headsign!.isNotEmpty ? " • ${leg.headsign}" : ''}',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.black,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(LucideIcons.arrowRight, size: 16),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${leg.startTime.hour}:${leg.startTime.minute.toString().padLeft(2, '0')} - ${leg.fromName}',
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
                    '${leg.endTime.hour}:${leg.endTime.minute.toString().padLeft(2, '0')} - ${leg.toName}',
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
        ),
      );
  }

  Widget _buildLegIcon() {
    return Icon(getLegIcon(leg.mode), size: 24, color: AppColors.black);
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
    if (leg.routeShortName != null) {
      final bg = _parseHexColor(leg.routeColor);
      final txt = _parseHexColor(leg.routeTextColor) ?? AppColors.black;
      return Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: bg ?? const Color(0x00000000),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            leg.routeShortName!.length > 0 ? leg.routeShortName! : getTransitModeName(leg.mode),
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
      getTransitModeName(leg.mode),
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
