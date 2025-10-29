import 'package:entaria_app/services/transitous_geocode_service.dart';
import 'package:entaria_app/utils/custom_page_route.dart';
import 'package:entaria_app/utils/leg_helper.dart'; // Added back
// Core Flutter widgets (no Material UI)
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';
import '../models/time_selection.dart';
import '../widgets/custom_card.dart';
import '../models/itinerary.dart';
import '../services/routing_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../utils/duration_formatter.dart';
import 'itinerary_detail_screen.dart';

class ItineraryListScreen extends StatefulWidget {
  final double fromLat;
  final double fromLon;
  final double toLat;
  final double toLon;
  final TimeSelection timeSelection;
  final TransitousLocationSuggestion? fromSelection;
  final TransitousLocationSuggestion? toSelection;

  const ItineraryListScreen({
    super.key,
    required this.fromLat,
    required this.fromLon,
    required this.toLat,
    required this.toLon,
    required this.timeSelection,
    this.fromSelection,
    this.toSelection,
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
      timeSelection: widget.timeSelection,
    ).then((itineraries) {
      return itineraries;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Search Results',
              // Unfocus any active text fields before returning to the map.
              onBackButtonPressed: () {
                FocusScope.of(context).unfocus();
                Navigator.of(context).pop();
              },
            ),
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
                        Navigator.of(context).push(CustomPageRoute(
                          child: ItineraryDetailScreen(itinerary: itineraries[index]),
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

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0x1A000000),
      highlightColor: const Color(0x0D000000),
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
        }
      ),
    );
  }
}

class ItineraryCard extends StatelessWidget {
  final Itinerary itinerary;

  const ItineraryCard({super.key, required this.itinerary});

  @override
  Widget build(BuildContext context) {
    return CustomCard(
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  formatDuration(itinerary.duration),
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
              style: const TextStyle(
                fontSize: 14,
                color: Color(0x80000000),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: itinerary.legs.map((leg) => LegWidget(leg: leg)).toList(),
            ),
            // Thin horizontal divider with vertical spacing, inset from sides (no Material Divider)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12.0, vertical: 10.0),
              child: SizedBox(
                height: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color(0x33000000), // semi‑transparent
                  ),
                ),
              ),
            ),
            // Bottom-right "More" action
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'More',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accent,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),
          ],
      ),
    );
  }
}

class LegWidget extends StatelessWidget {
  final Leg leg;

  const LegWidget({super.key, required this.leg});

  // Parse a hex colour string like "#FF0000" into a Flutter Color.
  Color? _parseHexColor(String? hex) {
    if (hex == null) return null;
    var cleaned = hex.replaceAll('#', '');
    if (cleaned.length == 6) cleaned = 'FF' + cleaned;
    if (cleaned.length != 8) return null;
    return Color(int.parse('0x$cleaned'));
  }

  @override
  Widget build(BuildContext context) {
    IconData icon = getLegIcon(leg.mode);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 18, // Match the height of the text container (14 font + 2*2 padding)
          child: Center(
            child: Icon(icon, size: 16, color: const Color(0x80000000)),
          ),
        ),
        const SizedBox(width: 4),
        if (leg.routeShortName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _parseHexColor(leg.routeColor) ?? const Color(0x00000000),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              leg.routeShortName!.length > 0 ? leg.routeShortName! : getTransitModeName(leg.mode),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _parseHexColor(leg.routeTextColor) ?? AppColors.black,
              ),
            ),
          ),
      ],
    );
  }
}
