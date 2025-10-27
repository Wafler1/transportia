
import 'package:flutter/material.dart';
import '../models/itinerary.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_icon_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class ItineraryDetailScreen extends StatelessWidget {
  final Itinerary itinerary;

  const ItineraryDetailScreen({super.key, required this.itinerary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
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

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          GlassIconButton(
            icon: LucideIcons.arrowLeft,
            onTap: () => Navigator.of(context).pop(),
          ),
          const SizedBox(width: 12),
          const Text(
            'Itinerary Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class LegDetailsWidget extends StatelessWidget {
  final Leg leg;

  const LegDetailsWidget({super.key, required this.leg});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.black.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildLegIcon(),
                const SizedBox(width: 8),
                Text(
                  leg.mode,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
                const Spacer(),
                Text(
                  '${(leg.duration / 60).round()} min',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (leg.routeShortName != null)
              Text(
                '${leg.routeShortName} ${leg.headsign ?? ''}',
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
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.black.withOpacity(0.5),
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
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.black.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegIcon() {
    IconData icon;
    switch (leg.mode) {
      case 'WALK':
        icon = LucideIcons.footprints;
        break;
      case 'BIKE':
        icon = LucideIcons.bike;
        break;
      case 'RENTAL':
        icon = LucideIcons.carTaxiFront;
        break;
      case 'CAR':
        icon = LucideIcons.carFront;
        break;
      case 'CAR_PARKING':
        icon = LucideIcons.parkingMeter;
        break;
      case 'CAR_DROPOFF':
        icon = LucideIcons.parkingMeter;
        break;
      case 'ODM':
        icon = LucideIcons.carTaxiFront;
        break;
      // TODO: FLEX and TRANSIT
      case 'TRAM':
        icon = LucideIcons.tramFront;
        break;
      case 'SUBWAY':
        icon = LucideIcons.squareArrowDown;
        break;
      case 'FERRY':
        icon = LucideIcons.ship;
        break;
      case 'AIRPLANE':
        icon = LucideIcons.planeTakeoff;
        break;
      case 'SUBURBAN':
        icon = LucideIcons.tramFront;
        break;
      case 'BUS':
        icon = LucideIcons.busFront;
        break;
      case 'COACH':
        icon = LucideIcons.bus;
        break;
      case 'RAIL':
        icon = LucideIcons.trainFront;
        break;
      case 'HIGHSPEED_RAIL':
        icon = LucideIcons.trainFront;
        break;
      case 'LONG_DISTANCE':
        icon = LucideIcons.trainFront;
        break;
      case 'NIGHT_RAIL':
        icon = LucideIcons.trainFront;
        break;
      case 'REGIONAL_FAST_RAIL':
        icon = LucideIcons.trainFront;
        break;
      case 'REGIONAL_RAIL':
        icon = LucideIcons.trainFront;
        break;
      case 'CABLE_CAR':
        icon = LucideIcons.cableCar;
        break;
      case 'AERIAL_LIFT':
        icon = LucideIcons.cableCar;
        break;
      case 'FUNICULAR':
        icon = LucideIcons.cableCar;
        break;
      case 'AREAL_LIFT':
        icon = LucideIcons.cableCar;
        break;
      case 'METRO':
        icon = LucideIcons.squareArrowDown;
        break;
      default:
        icon = LucideIcons.circleQuestionMark;  
    }
    return Icon(icon, size: 24, color: AppColors.black);
  }
}
