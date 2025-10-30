import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_colors.dart';
import '../models/time_selection.dart';
import '../models/route_field_kind.dart';
import '../models/stop_time.dart';
import '../services/location_service.dart';
import '../services/stop_times_service.dart';
import '../services/transitous_geocode_service.dart';
import '../utils/leg_helper.dart' show getLegIcon;
import '../widgets/load_more_button.dart';
import '../widgets/route_suggestions_overlay.dart';
import '../widgets/time_selection_overlay.dart';
import '../widgets/validation_toast.dart';

class TimetablesScreen extends StatefulWidget {
  const TimetablesScreen({super.key});

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
  List<TransitousLocationSuggestion> _suggestions = [];
  bool _isFetchingSuggestions = false;
  int _suggestionRequestId = 0;
  bool _hasLocationPermission = false;
  LatLng? _lastUserLatLng;
  TransitousLocationSuggestion? _selectedStop;
  List<StopTime>? _stopTimes;
  bool _isLoadingStopTimes = false;
  String? _nextPageCursor;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _searchFocus.addListener(_onFocusChanged);
    _checkLocationPermission();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    final granted = await LocationService.ensurePermission();
    if (!mounted) return;
    setState(() => _hasLocationPermission = granted);

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
    if (!_showTimeSelectionOverlay) {
      _searchFocus.unfocus();
    }
    setState(() {
      _showTimeSelectionOverlay = !_showTimeSelectionOverlay;
    });
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
        _suggestions = results;
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

  void _onSuggestionSelected(TransitousLocationSuggestion suggestion) {
    setState(() {
      _searchController.text = suggestion.name;
      _selectedStop = suggestion;
      _searchFocus.unfocus();
      _suggestions = [];
    });
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
    });

    try {
      final response = await StopTimesService.fetchStopTimes(
        stopId: _selectedStop?.id ?? '',
        n: 25,
      );

      if (!mounted) return;

      setState(() {
        _stopTimes = response.stopTimes;
        _nextPageCursor = response.nextPageCursor;
        _isLoadingStopTimes = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingStopTimes = false;
      });

      showValidationToast(context, 'Failed to load stop times');
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || _nextPageCursor == null || _selectedStop?.id == null) {
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
      );

      if (!mounted) return;

      setState(() {
        _stopTimes = [...?_stopTimes, ...response.stopTimes];
        _nextPageCursor = response.nextPageCursor;
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
    final showSuggestions = _searchFocus.hasFocus;

    return PopScope(
      canPop: !_searchFocus.hasFocus && !_showTimeSelectionOverlay,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (_showTimeSelectionOverlay) {
            _toggleTimeSelectionOverlay();
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
                                  color: AppColors.accent.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(
                                  LucideIcons.clock,
                                  size: 24,
                                  color: AppColors.accent,
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Column(
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
                                      color: Color(0x66000000),
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
                                  color: const Color(0xFFFFFFFF),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0x1A000000)),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x14000000),
                                      blurRadius: 10,
                                      offset: Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    const Icon(
                                      LucideIcons.search,
                                      size: 20,
                                      color: Color(0x66000000),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: CupertinoTextField(
                                        controller: _searchController,
                                        focusNode: _searchFocus,
                                        placeholder: 'Search for a stop...',
                                        placeholderStyle: const TextStyle(
                                          color: Color(0x66000000),
                                          fontSize: 16,
                                        ),
                                        style: const TextStyle(
                                          color: AppColors.black,
                                          fontSize: 16,
                                        ),
                                        decoration: null,
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        cursorColor: AppColors.accent,
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
                                        child: const Padding(
                                          padding: EdgeInsets.only(left: 8),
                                          child: Icon(
                                            LucideIcons.x,
                                            size: 20,
                                            color: Color(0x66000000),
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
                                  onTap: () {
                                    _searchFocus.unfocus();
                                    _toggleTimeSelectionOverlay();
                                  },
                                ),
                              ),
                              const Spacer(),
                              _SearchButton(
                                onTap: _onSearch,
                              ),
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
                              ? ListView.builder(
                                  padding: const EdgeInsets.only(
                                    left: 20,
                                    right: 20,
                                    top: 12,
                                    bottom: 96, // Padding for navbar
                                  ),
                                  itemCount: _stopTimes!.length + (_nextPageCursor != null ? 1 : 0),
                                  itemBuilder: (context, index) {
                                    if (index == _stopTimes!.length) {
                                      // Load more button
                                    return LoadMoreButton(
                                      onTap: _loadMore,
                                      isLoading: _isLoadingMore,
                                    );
                                    }
                                    return _StopTimeCard(
                                      stopTime: _stopTimes![index],
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
                                            color: const Color(0x0A000000),
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          child: const Icon(
                                            LucideIcons.trainFront,
                                            size: 40,
                                            color: Color(0x33000000),
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                        const Text(
                                          'Search for a stop',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        const Text(
                                          'Enter a stop name above to view\ndepartures and arrivals',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0x66000000),
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
                              isLoading: _isFetchingSuggestions,
                              onSuggestionTap: (_, suggestion) =>
                                  _onSuggestionSelected(suggestion),
                              onDismissRequest: () {
                                _searchFocus.unfocus();
                              },
                            ),
                    ),
                  ),
                ),
                CompositedTransformFollower(
                  link: _timeSelectionLayerLink,
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
                    child: !_showTimeSelectionOverlay
                        ? const SizedBox.shrink()
                        : TimeSelectionOverlay(
                            width: MediaQuery.of(context).size.width - 40,
                            currentSelection: _timeSelection,
                            onSelectionChanged: _onTimeSelectionChanged,
                            onDismiss: _toggleTimeSelectionOverlay,
                            showDepartArriveToggle: false,
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
  });

  final TimeSelection timeSelection;
  final VoidCallback onTap;

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
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 90),
        scale: _pressed ? 0.97 : 1.0,
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            color: _pressed
                ? const Color(0x14000000)
                : const Color(0x0F000000),
            border: Border.all(color: const Color(0x11000000)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                LucideIcons.clock,
                size: 16,
                color: AppColors.black,
              ),
              const SizedBox(width: 8),
              Text(
                widget.timeSelection.toDisplayString(),
                style: const TextStyle(
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
  const _SearchButton({
    required this.onTap,
  });

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
                ? const Color.fromARGB(255, 0, 105, 124)
                : AppColors.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: const Text(
            'Search',
            style: TextStyle(
              color: AppColors.white,
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

  String _formatTime(DateTime? dateTime) {
    if (dateTime == null) return '-';
    // Convert to local time
    final local = dateTime.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Color _parseHexColor(String hexString) {
    try {
      final buffer = StringBuffer();
      if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
      buffer.write(hexString.replaceFirst('#', ''));
      return Color(int.parse(buffer.toString(), radix: 16));
    } catch (_) {
      return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final routeColor = stopTime.routeColor != null
        ? _parseHexColor(stopTime.routeColor!)
        : AppColors.accent;
    final routeTextColor = stopTime.routeTextColor != null
        ? _parseHexColor(stopTime.routeTextColor!)
        : AppColors.white;

    final modeIcon = getLegIcon(stopTime.mode);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0x1A000000)),
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
              color: const Color(0x66000000),
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
                    constraints: const BoxConstraints(
                      minWidth: 30,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
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
                    style: const TextStyle(
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
                Text(
                  'Arr ${_formatTime(stopTime.place.arrival)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Dep ${_formatTime(stopTime.place.departure)}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0x99000000),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// LoadMoreButton widget has been moved to lib/widgets/load_more_button.dart
