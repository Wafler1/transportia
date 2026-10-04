import 'dart:async';

import 'package:flutter/cupertino.dart'
    show CupertinoActivityIndicator, CupertinoSliverRefreshControl;
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../models/itinerary.dart';
import '../models/saved_trip.dart';
import '../services/saved_trips_service.dart';
import '../services/trip_details_service.dart';
import '../theme/app_colors.dart';
import '../utils/custom_page_route.dart';
import '../utils/duration_formatter.dart';
import '../utils/time_utils.dart';
import '../widgets/empty_state.dart';
import '../widgets/section_title.dart';
import 'itinerary_detail_screen.dart';

/// Lists trips the user chose to keep for later, offline viewing. Used both
/// tab-hosted (in the main navigation shell) and pushed standalone (when
/// demoted to a settings entry) — its content never changes, only whether
/// the caller wraps it with a back affordance.
class SavedTripsScreen extends StatefulWidget {
  const SavedTripsScreen({super.key});

  @override
  State<SavedTripsScreen> createState() => _SavedTripsScreenState();
}

class _SavedTripsScreenState extends State<SavedTripsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    await SavedTripsService.getSavedTrips();
    if (mounted) setState(() => _isLoading = false);
  }

  Future<void> _refresh() async {
    final trips = SavedTripsService.savedTripsListenable.value;
    await Future.wait(trips.map(_refreshTrip));
  }

  Future<void> _refreshTrip(SavedTrip trip) async {
    final tripIds = trip.itinerary.legs
        .map((leg) => leg.tripId)
        .whereType<String>()
        .where((id) => id.isNotEmpty)
        .toSet();
    if (tripIds.isEmpty) return;

    final updates = <String, Leg>{};
    await Future.wait(
      tripIds.map((tripId) async {
        try {
          final details = await TripDetailsService.fetchTripDetails(
            tripId: tripId,
          );
          if (details.legs.isNotEmpty) updates[tripId] = details.legs.first;
        } catch (_) {}
      }),
    );
    if (updates.isEmpty || !mounted) return;

    final newLegs = trip.itinerary.legs.map((leg) {
      final fresh = leg.tripId != null ? updates[leg.tripId] : null;
      return fresh != null ? leg.withRealTimeFrom(fresh) : leg;
    }).toList();
    await SavedTripsService.replaceTrip(
      trip.id,
      trip.itinerary.withLegs(newLegs),
    );
  }

  Future<void> _remove(String id) async {
    await SavedTripsService.removeTrip(id);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: AppColors.accentOf(context).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      LucideIcons.bookmark,
                      size: 24,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Saved Trips',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Kept for offline viewing',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.black.withValues(alpha: 0.4),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CupertinoActivityIndicator(radius: 14),
                    )
                  : ValueListenableBuilder<List<SavedTrip>>(
                      valueListenable: SavedTripsService.savedTripsListenable,
                      builder: (context, trips, _) => _buildList(trips),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<SavedTrip> trips) {
    final upcoming = trips.where((t) => !t.isPast).toList();
    final past = trips.where((t) => t.isPast).toList();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        CupertinoSliverRefreshControl(onRefresh: _refresh),
        if (trips.isEmpty)
          SliverFillRemaining(
            hasScrollBody: false,
            child: const EmptyState(
              title: 'No saved trips yet',
              subtitle:
                  'Save a trip from its details page, or long-press a '
                  'search result, to keep it here for offline viewing.',
              padding: EdgeInsets.symmetric(horizontal: 32, vertical: 32),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                if (upcoming.isNotEmpty) ...[
                  const SectionTitle(text: 'Upcoming'),
                  const SizedBox(height: 12),
                  for (final trip in upcoming) ...[
                    _SavedTripRow(trip: trip, onRemove: () => _remove(trip.id)),
                    const SizedBox(height: 10),
                  ],
                  const SizedBox(height: 16),
                ],
                if (past.isNotEmpty) ...[
                  const SectionTitle(text: 'Past'),
                  const SizedBox(height: 12),
                  for (final trip in past) ...[
                    _SavedTripRow(trip: trip, onRemove: () => _remove(trip.id)),
                    const SizedBox(height: 10),
                  ],
                ],
              ]),
            ),
          ),
      ],
    );
  }
}

class _SavedTripRow extends StatelessWidget {
  const _SavedTripRow({required this.trip, required this.onRemove});

  final SavedTrip trip;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          CustomPageRoute(
            child: ItineraryDetailScreen(
              itinerary: trip.itinerary,
              isSavedTrip: true,
              savedTripId: trip.id,
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.black.withValues(alpha: 0.07)),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(LucideIcons.bookmark, size: 20, color: accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${trip.fromName} → ${trip.toName}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${formatTime(trip.itinerary.startTime)} - '
                    '${formatTime(trip.itinerary.endTime)}  ·  '
                    '${formatDuration(trip.itinerary.duration)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onRemove,
              behavior: HitTestBehavior.opaque,
              child: const Icon(
                LucideIcons.trash2,
                size: 18,
                color: Color(0xFFFF3B30),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
