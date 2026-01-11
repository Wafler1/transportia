import 'dart:async';

import 'package:transportia/services/transitous_geocode_service.dart';
import 'package:transportia/utils/custom_page_route.dart';
import 'package:transportia/utils/leg_helper.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../models/time_selection.dart';
import '../widgets/custom_card.dart';
import '../models/itinerary.dart';
import '../providers/theme_provider.dart';
import '../services/routing_service.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../utils/color_utils.dart';
import '../utils/duration_formatter.dart';
import '../utils/time_utils.dart';
import 'itinerary_detail_screen.dart';
import '../widgets/load_more_button.dart';
// Pagination response model imported via RoutingService; no direct reference needed.

class ItineraryListScreen extends StatefulWidget {
  final FutureOr<double> fromLat;
  final FutureOr<double> fromLon;
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
  List<Itinerary> _itineraries = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _nextPageCursor;
  String? _previousPageCursor;
  bool _isLoadingPrevious = false;
  double? _fromLat;
  double? _fromLon;
  late final ScrollController _scrollController;
  bool _appliedInitialPreviousOffset = false;
  static const double _seePreviousScrollOffset = 40.0;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitial() async {
    setState(() => _isLoading = true);
    try {
      final fromLat = await Future<double>.value(widget.fromLat);
      final fromLon = await Future<double>.value(widget.fromLon);
      final response = await RoutingService.findRoutesPaginated(
        fromLat: fromLat,
        fromLon: fromLon,
        toLat: widget.toLat,
        toLon: widget.toLon,
        timeSelection: widget.timeSelection,
      );
      setState(() {
        _fromLat = fromLat;
        _fromLon = fromLon;
        _itineraries = response.itineraries;
        _nextPageCursor = response.nextPageCursor;
        _previousPageCursor = response.previousPageCursor;
        _isLoading = false;
      });
      _maybeApplyInitialPreviousOffset();
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextPageCursor == null) return;
    setState(() => _isLoadingMore = true);
    try {
      final fromLat = _fromLat ?? await Future<double>.value(widget.fromLat);
      final fromLon = _fromLon ?? await Future<double>.value(widget.fromLon);
      final response = await RoutingService.findRoutesPaginated(
        fromLat: fromLat,
        fromLon: fromLon,
        toLat: widget.toLat,
        toLon: widget.toLon,
        timeSelection: widget.timeSelection,
        pageCursor: _nextPageCursor,
      );
      setState(() {
        _fromLat = fromLat;
        _fromLon = fromLon;
        _itineraries.addAll(response.itineraries);
        _nextPageCursor = response.nextPageCursor;
        _previousPageCursor =
            response.previousPageCursor ?? _previousPageCursor;
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _loadPrevious() async {
    if (_isLoadingPrevious || _previousPageCursor == null) return;
    setState(() => _isLoadingPrevious = true);
    try {
      final fromLat = _fromLat ?? await Future<double>.value(widget.fromLat);
      final fromLon = _fromLon ?? await Future<double>.value(widget.fromLon);
      final response = await RoutingService.findRoutesPaginated(
        fromLat: fromLat,
        fromLon: fromLon,
        toLat: widget.toLat,
        toLon: widget.toLon,
        timeSelection: widget.timeSelection,
        pageCursor: _previousPageCursor,
      );
      setState(() {
        _fromLat = fromLat;
        _fromLon = fromLon;
        _itineraries = [...response.itineraries, ..._itineraries];
        _previousPageCursor = response.previousPageCursor;
      });
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    } catch (_) {
      // Ignore network errors for now; button remains visible for retry.
    } finally {
      setState(() => _isLoadingPrevious = false);
    }
  }

  void _maybeApplyInitialPreviousOffset() {
    if (_appliedInitialPreviousOffset) return;
    if (_previousPageCursor == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_seePreviousScrollOffset);
      _appliedInitialPreviousOffset = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return PopScope(
      // Handle both back button and back gesture
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          // Unfocus any active text fields before returning to the map
          // This prevents fields from auto-focusing when returning via back gesture
          FocusScope.of(context).unfocus();
        }
      },
      child: Container(
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
                child: _isLoading
                    ? _buildLoadingSkeleton()
                    : _itineraries.isEmpty
                    ? Center(
                        child: Text(
                          'No routes found.',
                          style: TextStyle(
                            fontSize: 15,
                            color: AppColors.black.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final hasPreviousSlot = _previousPageCursor != null;
                          final hasNextSlot = _nextPageCursor != null;
                          final topSlotCount = hasPreviousSlot ? 1 : 0;
                          final bottomSlotCount = hasNextSlot ? 1 : 0;
                          final totalItems =
                              _itineraries.length +
                              topSlotCount +
                              bottomSlotCount;

                          return ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.only(bottom: 16),
                            itemCount: totalItems,
                            itemBuilder: (context, index) {
                              if (hasPreviousSlot && index == 0) {
                                return LoadMoreButton(
                                  onTap: _loadPrevious,
                                  isLoading: _isLoadingPrevious,
                                  label: 'See previous',
                                  icon: LucideIcons.chevronUp,
                                );
                              }

                              final adjustedIndex = index - topSlotCount;
                              if (adjustedIndex < _itineraries.length) {
                                final itin = _itineraries[adjustedIndex];
                                return GestureDetector(
                                  onTap: () {
                                    Navigator.of(context).push(
                                      CustomPageRoute(
                                        child: ItineraryDetailScreen(
                                          itinerary: itin,
                                        ),
                                      ),
                                    );
                                  },
                                  child: ItineraryCard(itinerary: itin),
                                );
                              }

                              if (hasNextSlot &&
                                  adjustedIndex == _itineraries.length) {
                                return LoadMoreButton(
                                  onTap: _loadMore,
                                  isLoading: _isLoadingMore,
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
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
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
    final delaySummary = _delaySummaryLabel();
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                formatDuration(itinerary.duration),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.black,
                ),
              ),
              const Spacer(),
              if (itinerary.isDirect)
                Text(
                  'Direct',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentOf(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${formatTime(itinerary.startTime)} - ${formatTime(itinerary.endTime)}',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.black.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: itinerary.legs.map((leg) => LegWidget(leg: leg)).toList(),
          ),
          // Thin horizontal divider with vertical spacing, inset from sides (no Material Divider)
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 10.0,
            ),
            child: SizedBox(
              height: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.2),
                ),
              ),
            ),
          ),
          // Bottom row with stats on left and "More" action on right
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side: transfers, calories, alerts
              Row(
                children: [
                  // Transfers
                  Icon(
                    LucideIcons.repeat,
                    size: 16,
                    color: AppColors.black.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${itinerary.transfers}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.black.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Calories (only show if there's walking)
                  if (itinerary.walkingDistance > 0) ...[
                    Icon(
                      LucideIcons.flame,
                      size: 16,
                      color: AppColors.black.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${itinerary.calories}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.black.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  if (delaySummary != null) ...[
                    Icon(
                      LucideIcons.clock,
                      size: 16,
                      color: AppColors.black.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      delaySummary,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.black.withValues(alpha: 0.8),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // Alerts (only show if there are alerts)
                  if (itinerary.alertsCount > 0) ...[
                    Icon(
                      LucideIcons.triangleAlert,
                      size: 16,
                      color: AppColors.black.withValues(alpha: 0.6),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${itinerary.alertsCount}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.black.withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ],
              ),
              // Right side: "More" action
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'More',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 16,
                    color: AppColors.accentOf(context),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String? _delaySummaryLabel() {
    int affected = 0;
    bool hasPositive(Duration? d) => d != null && d.inMinutes > 0;
    bool hasNegative(Duration? d) => d != null && d.inMinutes < 0;

    for (final leg in itinerary.legs) {
      final depDelay = computeDelay(leg.scheduledStartTime, leg.startTime);
      final arrDelay = computeDelay(leg.scheduledEndTime, leg.endTime);
      if (hasPositive(depDelay) ||
          hasPositive(arrDelay) ||
          hasNegative(depDelay) ||
          hasNegative(arrDelay)) {
        affected++;
      }
    }

    if (affected == 0) return null;
    return '$affected';
  }
}

class LegWidget extends StatelessWidget {
  final Leg leg;

  const LegWidget({super.key, required this.leg});

  @override
  Widget build(BuildContext context) {
    IconData icon = getLegIcon(leg.mode);
    final routeColor = parseHexColor(leg.routeColor);
    final badgeColor =
        routeColor ??
        (leg.mode == 'WALK'
            ? const Color(0x00000000)
            : AppColors.accentOf(context));
    final labelColor =
        parseHexColor(leg.routeTextColor) ??
        (routeColor == null && leg.mode != 'WALK'
            ? AppColors.solidWhite
            : AppColors.black);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height:
              18, // Match the height of the text container (14 font + 2*2 padding)
          child: Center(
            child: Icon(
              icon,
              size: 16,
              color: AppColors.black.withValues(alpha: 0.5),
            ),
          ),
        ),
        const SizedBox(width: 4),
        if (leg.displayName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: badgeColor,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              leg.displayName!.length > 0
                  ? leg.displayName!
                  : getTransitModeName(leg.mode),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: labelColor,
              ),
            ),
          ),
      ],
    );
  }
}
