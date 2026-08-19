import 'dart:async';

import 'package:transportia/services/transitous_geocode_service.dart';
import 'package:transportia/utils/custom_page_route.dart';
import 'package:transportia/utils/leg_helper.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../models/time_selection.dart';
import '../widgets/custom_card.dart';
import '../widgets/empty_state.dart';
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
import '../widgets/skeletons/skeleton_list.dart';
import '../l10n/app_localizations.dart';

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
  int _centerIndex = 0;
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
  static const Key _centerKey = ValueKey('itineraries-center');

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
        _centerIndex = 0;
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
        _centerIndex += response.itineraries.length;
        _previousPageCursor = response.previousPageCursor;
      });
    } catch (_) {
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
      final minExtent = _scrollController.position.minScrollExtent;
      _scrollController.jumpTo(minExtent + _seePreviousScrollOffset);
      _appliedInitialPreviousOffset = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    context.watch<ThemeProvider>();
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          FocusScope.of(context).unfocus();
        }
      },
      child: Container(
        color: AppColors.white,
        child: SafeArea(
          child: Column(
            children: [
              CustomAppBar(
                title: l10n.itineraryLabelSearchResults,
                backText: l10n.screenItineraryLabelBack,
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
                        child: EmptyState(
                          title: l10n.itineraryLabelNoRoutesFound,
                          titleStyle: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: AppColors.black.withValues(alpha: 0.5),
                          ),
                        ),
                      )
                    : Builder(
                        builder: (context) {
                          final hasPreviousSlot = _previousPageCursor != null;
                          final hasNextSlot = _nextPageCursor != null;
                          final beforeItems = _itineraries.sublist(
                            0,
                            _centerIndex,
                          );
                          final afterItems = _itineraries.sublist(_centerIndex);
                          final beforeCount =
                              beforeItems.length + (hasPreviousSlot ? 1 : 0);
                          final afterCount =
                              afterItems.length + (hasNextSlot ? 1 : 0);

                          Widget buildItineraryTile(Itinerary itin) {
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

                          return CustomScrollView(
                            controller: _scrollController,
                            center: _centerKey,
                            slivers: [
                              SliverList(
                                // Within a reverse-growth sliver, delegate
                                // index 0 is adjacent to the center anchor, so
                                // items must be listed nearest-first with the
                                // "See previous" button last (i.e. farthest
                                // away, requiring a scroll up to reach it).
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  if (index < beforeItems.length) {
                                    final itin =
                                        beforeItems[beforeItems.length -
                                            1 -
                                            index];
                                    return buildItineraryTile(itin);
                                  }
                                  return LoadMoreButton(
                                    onTap: _loadPrevious,
                                    isLoading: _isLoadingPrevious,
                                    label: l10n.itineraryLabelSeePrevious,
                                    icon: LucideIcons.chevronUp,
                                  );
                                }, childCount: beforeCount),
                              ),
                              SliverList(
                                key: _centerKey,
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  if (index < afterItems.length) {
                                    return buildItineraryTile(
                                      afterItems[index],
                                    );
                                  }
                                  if (hasNextSlot &&
                                      index == afterItems.length) {
                                    return LoadMoreButton(
                                      onTap: _loadMore,
                                      isLoading: _isLoadingMore,
                                      label: l10n.itineraryListLoadMoreButton,
                                    );
                                  }
                                  return const SizedBox.shrink();
                                }, childCount: afterCount),
                              ),
                              const SliverToBoxAdapter(
                                child: SizedBox(height: 16),
                              ),
                            ],
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
    return const SkeletonList(
      itemCount: 5,
      itemHeight: 100,
      itemMargin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }
}

class ItineraryCard extends StatefulWidget {
  final Itinerary itinerary;

  const ItineraryCard({super.key, required this.itinerary});

  @override
  State<ItineraryCard> createState() => _ItineraryCardState();
}

class _ItineraryCardState extends State<ItineraryCard>
    with SingleTickerProviderStateMixin {
  static const Color _softRed = Color(0xFFE57373);

  late final Timer _departInTimer;
  late final AnimationController _realTimeIconController;

  @override
  void initState() {
    super.initState();
    _departInTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
    _realTimeIconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _departInTimer.cancel();
    _realTimeIconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final itinerary = widget.itinerary;
    final delaySummary = _delaySummaryLabel();
    final hasDeparted = _hasDeparted();
    final departureText = _departureText();
    final l10n = AppLocalizations.of(context)!;
    final firstNonWalkingLeg = itinerary.legs
        .where((leg) => leg.mode != 'WALK')
        .firstOrNull;
    final hasFirstLegRealTime = firstNonWalkingLeg?.realTime ?? false;
    return CustomCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      formatDuration(itinerary.duration),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.black,
                      ),
                    ),
                    Text(
                      departureText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: hasDeparted
                            ? _softRed
                            : AppColors.black.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (itinerary.isDirect) ...[
                    Text(
                      l10n.itineraryListDirect,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.accentOf(context),
                      ),
                    ),
                    if (hasFirstLegRealTime) const SizedBox(width: 8),
                  ],
                  if (hasFirstLegRealTime)
                    FadeTransition(
                      opacity: Tween<double>(
                        begin: 1.0,
                        end: 0.4,
                      ).animate(_realTimeIconController),
                      child: Icon(
                        LucideIcons.radio,
                        size: 14,
                        color: AppColors.accentOf(context),
                      ),
                    ),
                ],
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
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
                    const SizedBox(width: 12),
                  ],
                  if (itinerary.hasTicketInfo)
                    Icon(
                      LucideIcons.ticket,
                      size: 16,
                      color: AppColors.black.withValues(alpha: 0.6),
                    ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    l10n.itineraryListMoreRows,
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

    for (final leg in widget.itinerary.legs) {
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

  int _secondsUntilDeparture() {
    return widget.itinerary.startTime.difference(DateTime.now()).inSeconds;
  }

  bool _hasDeparted() => _secondsUntilDeparture() <= 0;

  String _departureText() {
    final l10n = AppLocalizations.of(context)!;
    final secondsUntil = _secondsUntilDeparture();
    if (secondsUntil <= 0) return l10n.itineraryListDeparted;
    if (secondsUntil < 60) return l10n.itineraryListDepartNow;
    return l10n.itineraryListDepartIn(formatDuration(secondsUntil));
  }
}

class LegWidget extends StatelessWidget {
  final Leg leg;

  const LegWidget({super.key, required this.leg});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
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
          height: 18,
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
                  : getTransitModeName(loc, leg.mode),
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
