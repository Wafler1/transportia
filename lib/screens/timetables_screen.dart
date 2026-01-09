import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../models/time_selection.dart';
import '../models/route_field_kind.dart';
import '../models/saved_place.dart';
import '../models/stop_time.dart';
import '../screens/connection_info_screen.dart';
import '../services/location_service.dart';
import '../services/saved_places_service.dart';
import '../services/stop_times_service.dart';
import '../services/transitous_geocode_service.dart';
import '../utils/color_utils.dart';
import '../utils/custom_page_route.dart';
import '../utils/leg_helper.dart' show getLegIcon;
import '../utils/time_utils.dart';
import '../widgets/load_more_button.dart';
import '../widgets/route_suggestions_overlay.dart';
import '../widgets/time_selection_overlay.dart';
import '../widgets/validation_toast.dart';

class TimetablesScreen extends StatefulWidget {
  const TimetablesScreen({super.key, this.initialStop});

  final TransitousLocationSuggestion? initialStop;

  @override
  State<TimetablesScreen> createState() => _TimetablesScreenState();
}

class _TimetablesScreenState extends State<TimetablesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  final LayerLink _searchFieldLink = LayerLink();
  final LayerLink _timeSelectionLayerLink = LayerLink();

  TimeSelection _timeSelection = TimeSelection.now();
  bool _showTimeSelectionOverlay = false;
  bool _suppressTimeSelectionReopen = false;
  List<TransitousLocationSuggestion> _suggestions = [];
  bool _isFetchingSuggestions = false;
  int _suggestionRequestId = 0;
  List<SavedPlace> _savedPlaces = [];
  LatLng? _lastUserLatLng;
  TransitousLocationSuggestion? _selectedStop;
  List<StopTime>? _stopTimes;
  bool _isLoadingStopTimes = false;
  String? _nextPageCursor;
  bool _isLoadingMore = false;
  String? _previousPageCursor;
  bool _isLoadingPrevious = false;
  late final ScrollController _resultsScrollController;
  bool _appliedInitialPreviousOffset = false;
  static const double _seePreviousScrollOffset = 40.0;

  bool get _hasPreviousPage => _previousPageCursor?.isNotEmpty ?? false;
  bool get _hasNextPage => _nextPageCursor?.isNotEmpty ?? false;
  DateTime? get _startTimeParam =>
      _timeSelection.isNow ? null : _timeSelection.dateTime;

  String? _normalizeCursor(String? cursor) {
    if (cursor == null || cursor.isEmpty) return null;
    return cursor;
  }

  @override
  void initState() {
    super.initState();
    _resultsScrollController = ScrollController();
    _searchController.addListener(_onSearchTextChanged);
    _searchFocus.addListener(_onFocusChanged);
    _checkLocationPermission();
    unawaited(_loadSavedPlaces());
    _applyInitialStop(widget.initialStop);
  }

  @override
  void didUpdateWidget(covariant TimetablesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialStop?.id != oldWidget.initialStop?.id) {
      _applyInitialStop(widget.initialStop);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    _resultsScrollController.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final granted = await LocationService.ensurePermission();
    if (!mounted) return;

    if (granted) {
      try {
        final pos = await LocationService.currentPosition();
        if (mounted) {
          setState(() {
            _lastUserLatLng = LatLng(pos.latitude, pos.longitude);
          });
        }
      } catch (_) {
        // Silently fail if location is not available
      }
    }
  }

  Future<void> _loadSavedPlaces() async {
    final places = await SavedPlacesService.loadPlaces();
    if (!mounted) return;
    setState(() {
      _savedPlaces = places;
    });
  }

  Future<void> _recordSavedPlace(
    TransitousLocationSuggestion suggestion,
  ) async {
    final name = suggestion.name.trim();
    if (name.isEmpty) return;
    final selected = SavedPlace(
      name: name,
      type: suggestion.type,
      lat: suggestion.lat,
      lon: suggestion.lon,
      importance: SavedPlace.defaultImportance,
      city: suggestion.defaultArea,
      countryCode: suggestion.country,
    );
    final updated = SavedPlacesService.applySelection(_savedPlaces, selected);
    if (!mounted) return;
    setState(() {
      _savedPlaces = updated;
    });
    unawaited(SavedPlacesService.savePlaces(updated));
  }

  void _onFocusChanged() {
    setState(() {});
    // Show overlay on focus if field is empty or has less than 3 characters
    if (_searchFocus.hasFocus) {
      _onSearchTextChanged();
    }
  }

  void _onTimeSelectionChanged(TimeSelection newSelection) {
    setState(() {
      _timeSelection = newSelection;
    });
  }

  void _toggleTimeSelectionOverlay() {
    if (_showTimeSelectionOverlay) {
      _closeTimeSelectionOverlay();
    } else {
      _openTimeSelectionOverlay();
    }
  }

  void _openTimeSelectionOverlay() {
    if (_showTimeSelectionOverlay) return;
    _searchFocus.unfocus();
    setState(() {
      _showTimeSelectionOverlay = true;
    });
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Time selection',
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) {
        return TimeSelectionOverlay(
          currentSelection: _timeSelection,
          onSelectionChanged: _onTimeSelectionChanged,
          onDismiss: _closeTimeSelectionOverlay,
          showDepartArriveToggle: false,
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    ).then((_) {
      if (!mounted) return;
      if (_showTimeSelectionOverlay) {
        setState(() => _showTimeSelectionOverlay = false);
      }
    });
  }

  void _closeTimeSelectionOverlay() {
    if (!_showTimeSelectionOverlay) return;
    Navigator.of(context, rootNavigator: true).maybePop();
  }

  void _handleTimeButtonTapDown() {
    if (_showTimeSelectionOverlay) {
      _suppressTimeSelectionReopen = true;
      _closeTimeSelectionOverlay();
    }
  }

  void _handleTimeButtonTapCancel() {
    _suppressTimeSelectionReopen = false;
  }

  void _handleTimeButtonTap() {
    if (_suppressTimeSelectionReopen) {
      _suppressTimeSelectionReopen = false;
      return;
    }
    _toggleTimeSelectionOverlay();
  }

  void _onSearchTextChanged() {
    final query = _searchController.text.trim();
    setState(() {});

    // Show overlay on focus even with empty query
    if (_searchFocus.hasFocus) {
      if (query.length >= 3) {
        _requestSuggestions(query);
      } else {
        // Still show overlay, just with "Keep typing" message
        setState(() {
          _suggestions = [];
          _isFetchingSuggestions = false;
        });
      }
    } else {
      setState(() {
        _suggestions = [];
        _isFetchingSuggestions = false;
      });
    }
  }

  void _applyInitialStop(TransitousLocationSuggestion? initialStop) {
    if (initialStop == null) return;
    _selectedStop = initialStop;
    _searchController.text = initialStop.name;
    _suggestions = [];
    _isFetchingSuggestions = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _onSearch();
    });
  }

  Future<void> _requestSuggestions(String query) async {
    final requestId = ++_suggestionRequestId;
    setState(() => _isFetchingSuggestions = true);

    try {
      final results = await TransitousGeocodeService.fetchSuggestions(
        text: query,
        type: 'STOP',
        placeBias: _lastUserLatLng,
      );

      if (requestId != _suggestionRequestId) return;
      if (!mounted) return;

      setState(() {
        _suggestions = _prioritizeSavedSuggestions(results);
        _isFetchingSuggestions = false;
      });
    } catch (e) {
      if (requestId != _suggestionRequestId) return;
      if (!mounted) return;

      setState(() {
        _suggestions = [];
        _isFetchingSuggestions = false;
      });
    }
  }

  List<TransitousLocationSuggestion> _prioritizeSavedSuggestions(
    List<TransitousLocationSuggestion> results,
  ) {
    if (_savedPlaces.isEmpty) return results;
    final importanceByKey = <String, int>{
      for (final place in _savedPlaces) place.key: place.importance,
    };
    final indexBySuggestion = <TransitousLocationSuggestion, int>{};
    for (int i = 0; i < results.length; i++) {
      indexBySuggestion[results[i]] = i;
    }
    final ordered = List<TransitousLocationSuggestion>.from(results);
    ordered.sort((a, b) {
      final aKey = SavedPlace.buildKey(type: a.type, lat: a.lat, lon: a.lon);
      final bKey = SavedPlace.buildKey(type: b.type, lat: b.lat, lon: b.lon);
      final aImportance = importanceByKey[aKey];
      final bImportance = importanceByKey[bKey];
      final aSaved = aImportance != null;
      final bSaved = bImportance != null;
      if (aSaved != bSaved) {
        return aSaved ? -1 : 1;
      }
      if (aImportance != null && bImportance != null) {
        final diff = bImportance.compareTo(aImportance);
        if (diff != 0) return diff;
      }
      return indexBySuggestion[a]!.compareTo(indexBySuggestion[b]!);
    });
    return ordered;
  }

  void _onSuggestionSelected(TransitousLocationSuggestion suggestion) {
    unawaited(_recordSavedPlace(suggestion));
    setState(() {
      _searchController.text = suggestion.name;
      _selectedStop = suggestion;
      _searchFocus.unfocus();
      _suggestions = [];
    });
  }

  List<StopTime> _deduplicateStopTimes(List<StopTime> stopTimes) {
    final seen = <String>{};
    final deduplicated = <StopTime>[];

    for (final stopTime in stopTimes) {
      // Create a unique key based on tripId, departure time, and headsign
      final departureTime = stopTime.place.departure?.toIso8601String() ?? '';
      final key = '${stopTime.tripId}|$departureTime|${stopTime.headsign}';

      if (!seen.contains(key)) {
        seen.add(key);
        deduplicated.add(stopTime);
      }
    }

    return deduplicated;
  }

  Future<void> _onSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      showValidationToast(context, 'Please enter a stop name');
      return;
    }

    // Check if user selected a stop from the list
    if (_selectedStop?.id == null) {
      showValidationToast(context, 'Please select a stop from the list');
      return;
    }

    _searchFocus.unfocus();

    setState(() {
      _isLoadingStopTimes = true;
      _stopTimes = null;
      _nextPageCursor = null;
      _previousPageCursor = null;
      _isLoadingMore = false;
      _isLoadingPrevious = false;
      _appliedInitialPreviousOffset = false;
    });
    if (_resultsScrollController.hasClients) {
      _resultsScrollController.jumpTo(0);
    }

    try {
      final response = await StopTimesService.fetchStopTimes(
        stopId: _selectedStop?.id ?? '',
        n: 20,
        startTime: _startTimeParam,
        arriveBy: _timeSelection.isArriveBy,
      );

      if (!mounted) return;

      setState(() {
        _stopTimes = _deduplicateStopTimes(response.stopTimes);
        _nextPageCursor = _normalizeCursor(response.nextPageCursor);
        _previousPageCursor = _normalizeCursor(response.previousPageCursor);
        _isLoadingStopTimes = false;
      });
      _maybeApplyInitialPreviousOffset();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingStopTimes = false;
        _previousPageCursor = null;
        _isLoadingPrevious = false;
      });

      showValidationToast(context, 'Failed to load stop times');
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore ||
        _nextPageCursor == null ||
        _selectedStop?.id == null) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final response = await StopTimesService.fetchStopTimes(
        stopId: _selectedStop?.id ?? '',
        n: 25,
        pageCursor: _nextPageCursor,
        startTime: _startTimeParam,
        arriveBy: _timeSelection.isArriveBy,
      );

      if (!mounted) return;

      setState(() {
        // Deduplicate the combined list to avoid duplicates across pages
        _stopTimes = _deduplicateStopTimes([
          ...?_stopTimes,
          ...response.stopTimes,
        ]);
        _nextPageCursor = _normalizeCursor(response.nextPageCursor);
        _previousPageCursor = _normalizeCursor(
          response.previousPageCursor ?? _previousPageCursor,
        );
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
      });

      showValidationToast(context, 'Failed to load more stop times');
    }
  }

  Future<void> _loadPrevious() async {
    if (_isLoadingPrevious || !_hasPreviousPage || _selectedStop?.id == null) {
      return;
    }

    setState(() {
      _isLoadingPrevious = true;
    });

    try {
      final response = await StopTimesService.fetchStopTimes(
        stopId: _selectedStop?.id ?? '',
        n: 25,
        pageCursor: _previousPageCursor,
        startTime: _startTimeParam,
        arriveBy: _timeSelection.isArriveBy,
      );

      if (!mounted) return;

      setState(() {
        _stopTimes = _deduplicateStopTimes([
          ...response.stopTimes,
          ...?_stopTimes,
        ]);
        _previousPageCursor = _normalizeCursor(response.previousPageCursor);
        _isLoadingPrevious = false;
      });

      if (_resultsScrollController.hasClients) {
        _resultsScrollController.jumpTo(0);
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingPrevious = false;
      });

      showValidationToast(context, 'Failed to load previous stop times');
    }
  }

  void _maybeApplyInitialPreviousOffset() {
    if (_appliedInitialPreviousOffset) return;
    if (!_hasPreviousPage) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_resultsScrollController.hasClients) return;
      _resultsScrollController.jumpTo(_seePreviousScrollOffset);
      _appliedInitialPreviousOffset = true;
    });
  }

  Widget _buildLoadingSkeleton() {
    return Shimmer.fromColors(
      baseColor: const Color(0x1A000000),
      highlightColor: const Color(0x0D000000),
      child: ListView.builder(
        padding: const EdgeInsets.only(
          left: 20,
          right: 20,
          top: 12,
          bottom: 96,
        ),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(14),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final showSuggestions = _searchFocus.hasFocus;

    return PopScope(
      canPop: !_searchFocus.hasFocus && !_showTimeSelectionOverlay,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_showTimeSelectionOverlay) {
            _closeTimeSelectionOverlay();
          } else if (_searchFocus.hasFocus) {
            _searchFocus.unfocus();
          }
        }
      },
      child: GestureDetector(
        onTap: () {
          _searchFocus.unfocus();
        },
        child: Container(
          color: AppColors.white,
          child: SafeArea(
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 48,
                                height: 48,
                                decoration: BoxDecoration(
                                  color: AppColors.accentOf(
                                    context,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  LucideIcons.clock,
                                  size: 24,
                                  color: AppColors.accentOf(context),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Timetables',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.black,
                                      height: 1.1,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Stop departures & arrivals',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Search field (styled like RouteFieldBox)
                          CompositedTransformTarget(
                            link: _searchFieldLink,
                            child: GestureDetector(
                              onTap: () {
                                // Prevent unfocus when tapping the field
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: AppColors.black.withValues(
                                      alpha: 0.1,
                                    ),
                                  ),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      LucideIcons.search,
                                      size: 20,
                                      color: AppColors.black.withValues(
                                        alpha: 0.4,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CupertinoTextField(
                                        controller: _searchController,
                                        focusNode: _searchFocus,
                                        placeholder: 'Search for a stop...',
                                        placeholderStyle: TextStyle(
                                          color: AppColors.black.withValues(
                                            alpha: 0.4,
                                          ),
                                          fontSize: 16,
                                        ),
                                        style: TextStyle(
                                          color: AppColors.black,
                                          fontSize: 16,
                                        ),
                                        decoration: null,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        cursorColor: AppColors.accentOf(
                                          context,
                                        ),
                                        maxLines: 1,
                                        textInputAction: TextInputAction.search,
                                        onSubmitted: (_) => _onSearch(),
                                      ),
                                    ),
                                    if (_searchController.text.isNotEmpty)
                                      GestureDetector(
                                        onTap: () {
                                          _searchController.clear();
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            left: 8,
                                          ),
                                          child: Icon(
                                            LucideIcons.x,
                                            size: 20,
                                            color: AppColors.black.withValues(
                                              alpha: 0.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          // Time and Search buttons
                          Row(
                            children: [
                              CompositedTransformTarget(
                                link: _timeSelectionLayerLink,
                                child: _TimeButton(
                                  timeSelection: _timeSelection,
                                  onTapDown: _handleTimeButtonTapDown,
                                  onTapCancel: _handleTimeButtonTapCancel,
                                  onTap: _handleTimeButtonTap,
                                ),
                              ),
                              const Spacer(),
                              _SearchButton(onTap: _onSearch),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Content area
                    Expanded(
                      child: _isLoadingStopTimes
                          ? _buildLoadingSkeleton()
                          : _stopTimes != null
                          ? Builder(
                              builder: (context) {
                                final hasPreviousSlot = _hasPreviousPage;
                                final hasNextSlot = _hasNextPage;
                                final totalItems =
                                    _stopTimes!.length +
                                    (hasPreviousSlot ? 1 : 0) +
                                    (hasNextSlot ? 1 : 0);

                                return ListView.builder(
                                  controller: _resultsScrollController,
                                  padding: const EdgeInsets.only(
                                    left: 20,
                                    right: 20,
                                    top: 0,
                                    bottom: 96, // Padding for navbar
                                  ),
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

                                    final adjustedIndex =
                                        index - (hasPreviousSlot ? 1 : 0);

                                    if (adjustedIndex < _stopTimes!.length) {
                                      final stopTime =
                                          _stopTimes![adjustedIndex];
                                      return GestureDetector(
                                        onTap: () {
                                          Navigator.of(context).push(
                                            CustomPageRoute(
                                              child: ConnectionInfoScreen(
                                                tripId: stopTime.tripId,
                                              ),
                                            ),
                                          );
                                        },
                                        child: _StopTimeCard(
                                          stopTime: stopTime,
                                        ),
                                      );
                                    }

                                    if (hasNextSlot &&
                                        adjustedIndex == _stopTimes!.length) {
                                      return LoadMoreButton(
                                        onTap: _loadMore,
                                        isLoading: _isLoadingMore,
                                      );
                                    }

                                    return const SizedBox.shrink();
                                  },
                                );
                              },
                            )
                          : Center(
                              child: Padding(
                                padding: const EdgeInsets.all(40),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        color: AppColors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Icon(
                                        LucideIcons.trainFront,
                                        size: 40,
                                        color: AppColors.black.withValues(
                                          alpha: 0.2,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    Text(
                                      'Search for a stop',
                                      style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.black,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Enter a stop name above to view\ndepartures and arrivals',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: AppColors.black.withValues(
                                          alpha: 0.4,
                                        ),
                                        height: 1.4,
                                      ),
                                    ),
                                    // Add padding at bottom for navbar
                                    const SizedBox(height: 96),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ],
                ),

                // Suggestions overlay
                Positioned(
                  left: 20,
                  right: 20,
                  top: 0,
                  child: CompositedTransformFollower(
                    link: _searchFieldLink,
                    showWhenUnlinked: false,
                    targetAnchor: Alignment.bottomLeft,
                    followerAnchor: Alignment.topLeft,
                    offset: const Offset(0, 8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (child, animation) {
                        final offsetTween = Tween<Offset>(
                          begin: const Offset(0, -0.05),
                          end: Offset.zero,
                        );
                        return FadeTransition(
                          opacity: animation,
                          child: SlideTransition(
                            position: animation.drive(offsetTween),
                            child: child,
                          ),
                        );
                      },
                      child: !showSuggestions
                          ? const SizedBox.shrink()
                          : RouteSuggestionsOverlay(
                              key: const ValueKey('suggestions'),
                              width: MediaQuery.of(context).size.width - 40,
                              activeField: RouteFieldKind.from, // Dummy value
                              fromController: _searchController,
                              toController: _searchController,
                              suggestions: _suggestions,
                              savedPlaces: _savedPlaces,
                              isLoading: _isFetchingSuggestions,
                              onSuggestionTap: (_, suggestion) =>
                                  _onSuggestionSelected(suggestion),
                              onDismissRequest: () {
                                _searchFocus.unfocus();
                              },
                              title: "Stop suggestions",
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeButton extends StatefulWidget {
  const _TimeButton({
    required this.timeSelection,
    required this.onTap,
    this.onTapDown,
    this.onTapCancel,
  });

  final TimeSelection timeSelection;
  final VoidCallback onTap;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapCancel;

  @override
  State<_TimeButton> createState() => _TimeButtonState();
}

class _TimeButtonState extends State<_TimeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) {
        widget.onTapDown?.call();
        setState(() => _pressed = true);
      },
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () {
        widget.onTapCancel?.call();
        setState(() => _pressed = false);
      },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.97 : 1.0,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _pressed
                ? AppColors.black.withValues(alpha: 0.08)
                : AppColors.black.withValues(alpha: 0.06),
            border: Border.all(color: AppColors.black.withValues(alpha: 0.07)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.clock, size: 16, color: AppColors.black),
              const SizedBox(width: 8),
              Text(
                widget.timeSelection.toDisplayString(),
                style: TextStyle(
                  color: AppColors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchButton extends StatefulWidget {
  const _SearchButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_SearchButton> createState() => _SearchButtonState();
}

class _SearchButtonState extends State<_SearchButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 80),
        scale: _pressed ? 0.985 : 1.0,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _pressed
                ? AppColors.accentOf(context).withValues(alpha: 0.85)
                : AppColors.accentOf(context),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Text(
            'Search',
            style: TextStyle(
              color: AppColors.solidWhite,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _StopTimeCard extends StatelessWidget {
  const _StopTimeCard({required this.stopTime});

  final StopTime stopTime;

  @override
  Widget build(BuildContext context) {
    final routeColor = parseHexColorOrAccent(context, stopTime.routeColor);
    final routeTextColor =
        parseHexColor(stopTime.routeTextColor) ?? AppColors.solidWhite;

    final modeIcon = getLegIcon(stopTime.mode);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.black.withValues(alpha: 0.1)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Mode icon (not in color badge)
            Icon(
              modeIcon,
              size: 24,
              color: AppColors.black.withValues(alpha: 0.4),
            ),
            const SizedBox(width: 12),
            // Route badge and destination in a column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Route badge (without icon)
                  Container(
                    constraints: const BoxConstraints(minWidth: 30),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: routeColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      stopTime.displayName,
                      style: TextStyle(
                        color: routeTextColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Destination
                  Text(
                    stopTime.headsign,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Times stacked vertically on the right
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _TimeWithDelayText(
                  label: 'Arr',
                  scheduled: stopTime.place.scheduledArrival,
                  actual: stopTime.place.arrival,
                ),
                const SizedBox(height: 4),
                _TimeWithDelayText(
                  label: 'Dep',
                  scheduled: stopTime.place.scheduledDeparture,
                  actual: stopTime.place.departure,
                  subdued: true,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeWithDelayText extends StatelessWidget {
  const _TimeWithDelayText({
    required this.label,
    required this.scheduled,
    required this.actual,
    this.subdued = false,
  });

  final String label;
  final DateTime? scheduled;
  final DateTime? actual;
  final bool subdued;

  @override
  Widget build(BuildContext context) {
    final display = formatTime(scheduled ?? actual, nullPlaceholder: '--:--');
    final delay = (scheduled != null && actual != null)
        ? computeDelay(scheduled!, actual!)
        : null;
    final baseColor = subdued
        ? AppColors.black.withValues(alpha: 0.6)
        : AppColors.black;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label $display',
          style: TextStyle(
            fontSize: 14,
            fontWeight: subdued ? FontWeight.w500 : FontWeight.w600,
            color: baseColor,
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
    );
  }
}

Color _delayColor(Duration delay) =>
    delay.isNegative ? const Color(0xFF2E7D32) : const Color(0xFFB26A00);

// LoadMoreButton widget has been moved to lib/widgets/load_more_button.dart
