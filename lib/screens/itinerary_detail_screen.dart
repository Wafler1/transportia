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
                _buildTitleWidget(),
                const Spacer(),
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
                Text(
                  '${leg.startTime.hour}:${leg.startTime.minute.toString().padLeft(2, '0')} - ${leg.fromName}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0x80000000),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(LucideIcons.arrowDown, size: 16),
                const SizedBox(width: 4),
                Text(
                  '${leg.endTime.hour}:${leg.endTime.minute.toString().padLeft(2, '0')} - ${leg.toName}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0x80000000),
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
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: bg ?? const Color(0x00000000),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          leg.routeShortName!,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: txt,
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
    );
  }
}
