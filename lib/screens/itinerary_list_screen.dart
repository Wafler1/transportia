import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import '../models/itinerary.dart';
import '../services/routing_service.dart';
import '../theme/app_colors.dart';
import '../widgets/glass_icon_button.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'itinerary_detail_screen.dart';

class ItineraryListScreen extends StatefulWidget {
  final double fromLat;
  final double fromLon;
  final double toLat;
  final double toLon;

  const ItineraryListScreen({
    super.key,
    required this.fromLat,
    required this.fromLon,
    required this.toLat,
    required this.toLon,
  });

  @override
  State<ItineraryListScreen> createState() => _ItineraryListScreenState();
}

class _ItineraryListScreenState extends State<ItineraryListScreen> {
  Future<List<Itinerary>>? _itinerariesFuture;

  @override
  void initState() {
    super.initState();
    _itinerariesFuture = RoutingService.findRoutes(
      fromLat: widget.fromLat,
      fromLon: widget.fromLon,
      toLat: widget.toLat,
      toLon: widget.toLon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: FutureBuilder<List<Itinerary>>(
                future: _itinerariesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _buildLoadingSkeleton();
                  }
                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error: ${snapshot.error}'),
                    );
                  }
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(
                      child: Text('No routes found.'),
                    );
                  }
                  final itineraries = snapshot.data!;
                  return ListView.builder(
                    itemCount: itineraries.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (context) =>
                              ItineraryDetailScreen(itinerary: itineraries[index]),
                        ));
                      },
                      child: ItineraryCard(itinerary: itineraries[index]),
                    );
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

  Widget _buildHeader() {
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
            'Search Results',
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

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: AppColors.black.withOpacity(0.1),
      highlightColor: AppColors.black.withOpacity(0.05),
      child: ListView.builder(
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Container(
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        },
      ),
    );
  }
}

class ItineraryCard extends StatelessWidget {
  final Itinerary itinerary;

  const ItineraryCard({super.key, required this.itinerary});

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
                Text(
                  '${(itinerary.duration / 60).round()} min',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.black,
                  ),
                ),
                const Spacer(),
                if (itinerary.isDirect)
                  const Text(
                    'Direct',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${itinerary.startTime.hour}:${itinerary.startTime.minute.toString().padLeft(2, '0')} - ${itinerary.endTime.hour}:${itinerary.endTime.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 14,
                color: AppColors.black.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: itinerary.legs.map((leg) => LegWidget(leg: leg)).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class LegWidget extends StatelessWidget {
  final Leg leg;

  const LegWidget({super.key, required this.leg});

  @override
  Widget build(BuildContext context) {
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

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppColors.black.withOpacity(0.5)),
        const SizedBox(width: 4),
        if (leg.routeShortName != null)
          Text(
            leg.routeShortName!,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.black,
            ),
          ),
      ],
    );
  }
}
