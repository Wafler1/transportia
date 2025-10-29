import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../models/time_selection.dart';
import '../models/route_field_kind.dart';
import '../services/transitous_geocode_service.dart';
import '../widgets/route_suggestions_overlay.dart';
import '../widgets/time_selection_overlay.dart';

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

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchTextChanged);
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
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

    if (query.length >= 3) {
      _requestSuggestions(query);
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
      final results = await TransitousGeocodeService.fetchSuggestions(text: query);

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
      _searchFocus.unfocus();
      _suggestions = [];
    });
  }

  void _onSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    _searchFocus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final showSuggestions = _searchFocus.hasFocus &&
        (_searchController.text.trim().length >= 3 || _isFetchingSuggestions);

    return PopScope(
      canPop: !_searchFocus.hasFocus,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _searchFocus.unfocus();
        }
      },
      child: GestureDetector(
        onTap: () => _searchFocus.unfocus(),
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

                          // Search field
                          CompositedTransformTarget(
                            link: _searchFieldLink,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0x0F000000),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: _searchFocus.hasFocus
                                      ? AppColors.accent.withOpacity(0.5)
                                      : const Color(0x11000000),
                                  width: _searchFocus.hasFocus ? 2 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Padding(
                                    padding: EdgeInsets.only(left: 16),
                                    child: Icon(
                                      LucideIcons.search,
                                      size: 20,
                                      color: Color(0x66000000),
                                    ),
                                  ),
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
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 14,
                                      ),
                                      cursorColor: AppColors.accent,
                                    ),
                                  ),
                                  if (_searchController.text.isNotEmpty)
                                    GestureDetector(
                                      onTap: () {
                                        _searchController.clear();
                                      },
                                      child: const Padding(
                                        padding: EdgeInsets.only(right: 16),
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

                          const SizedBox(height: 12),

                          // Time and Search buttons
                          Row(
                            children: [
                              CompositedTransformTarget(
                                link: _timeSelectionLayerLink,
                                child: _TimeButton(
                                  timeSelection: _timeSelection,
                                  onTap: _toggleTimeSelectionOverlay,
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
                      child: Center(
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
                if (showSuggestions)
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
                      child: RouteSuggestionsOverlay(
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
