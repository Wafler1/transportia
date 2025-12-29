import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';
import '../models/time_selection.dart';
import '../models/trip_history_item.dart';
import '../services/favorites_service.dart';
import '../services/transitous_geocode_service.dart';
import '../widgets/route_field_box.dart';
import '../theme/app_colors.dart';

class BottomCard extends StatefulWidget {
  const BottomCard({
    super.key,
    required this.isCollapsed,
    required this.collapseProgress,
    required this.onHandleTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.fromCtrl,
    required this.toCtrl,
    required this.fromFocusNode,
    required this.toFocusNode,
    required this.showMyLocationDefault,
    required this.onUnfocus,
    required this.onSwapRequested,
    required this.routeFieldLink,
    required this.fromLoading,
    required this.toLoading,
    required this.fromSelection,
    required this.toSelection,
    required this.onSearch,
    required this.timeSelectionLayerLink,
    required this.onTimeSelectionTap,
    this.onTimeSelectionTapDown,
    this.onTimeSelectionTapCancel,
    required this.timeSelection,
    required this.recentTrips,
    required this.onRecentTripTap,
    required this.favorites,
    required this.onFavoriteTap,
    required this.hasLocationPermission,
    this.tripsRefreshKey = 0,
  });

  final bool isCollapsed;
  final double collapseProgress; // 0.0 (expanded) -> 1.0 (collapsed)
  final VoidCallback onHandleTap;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate; // dy delta
  final ValueChanged<double> onDragEnd; // velocity dy
  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final FocusNode fromFocusNode;
  final FocusNode toFocusNode;
  final bool showMyLocationDefault;
  final VoidCallback onUnfocus;
  final bool Function() onSwapRequested;
  final LayerLink routeFieldLink;
  final bool fromLoading;
  final bool toLoading;
  final TransitousLocationSuggestion? fromSelection;
  final TransitousLocationSuggestion? toSelection;
  final ValueChanged<TimeSelection> onSearch;
  final LayerLink timeSelectionLayerLink;
  final VoidCallback onTimeSelectionTap;
  final VoidCallback? onTimeSelectionTapDown;
  final VoidCallback? onTimeSelectionTapCancel;
  final TimeSelection timeSelection;
  final List<TripHistoryItem> recentTrips;
  final ValueChanged<TripHistoryItem> onRecentTripTap;
  final List<FavoritePlace> favorites;
  final ValueChanged<FavoritePlace> onFavoriteTap;
  final bool hasLocationPermission;
  final int tripsRefreshKey;

  @override
  State<BottomCard> createState() => _BottomCardState();
}

class _BottomCardState extends State<BottomCard> {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000), // ~10% black
            blurRadius: 14,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          // Don't unfocus if either text field is already focused
          // This prevents the flickering when tapping on an already-focused field
          if (widget.fromFocusNode.hasFocus || widget.toFocusNode.hasFocus) {
            return;
          }
          widget.onUnfocus();
        },
        child: Listener(
          onPointerDown: (_) {
            // Don't unfocus if either text field is already focused
            // This prevents the flickering when tapping on an already-focused field
            if (widget.fromFocusNode.hasFocus || widget.toFocusNode.hasFocus) {
              return;
            }
            widget.onUnfocus();
          },
          child: SafeArea(
            top: false,
            child: SizedBox.expand(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag handle area
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: widget.onHandleTap,
                    onVerticalDragStart: (_) => widget.onDragStart(),
                    onVerticalDragUpdate: (d) =>
                        widget.onDragUpdate(d.delta.dy),
                    onVerticalDragEnd: (d) =>
                        widget.onDragEnd(d.velocity.pixelsPerSecond.dy),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 18),
                        Container(
                          width: 48,
                          height: 6,
                          decoration: BoxDecoration(
                            color: AppColors.black.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                    ),
                  ),

                  // Title above the pickers; fade and collapse height progressively with drag
                  Builder(
                    builder: (context) {
                      // Start fading the header from mid -> collapsed
                      final fadeStart = 0.5;
                      final t =
                          ((widget.collapseProgress - fadeStart) /
                                  (1 - fadeStart))
                              .clamp(0.0, 1.0);
                      final opacity = 1.0 - Curves.easeOut.transform(t);
                      return GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: widget.onUnfocus,
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: opacity, // shrink height as it fades
                            child: Opacity(
                              opacity: opacity,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(12, 0, 12, 8),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Where to?',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),

                  // Route input fields
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Listener(
                      // Block parent Listener's onPointerDown from triggering unfocus
                      onPointerDown: (_) {
                        // Consume the event - don't call onUnfocus here
                      },
                      behavior: HitTestBehavior.opaque,
                      child: GestureDetector(
                        // Block parent GestureDetector's onTap from triggering unfocus
                        onTap: () {
                          // Consume the event - don't call onUnfocus here
                        },
                        behavior: HitTestBehavior.opaque,
                        child: RouteFieldBox(
                          fromController: widget.fromCtrl,
                          toController: widget.toCtrl,
                          fromFocusNode: widget.fromFocusNode,
                          toFocusNode: widget.toFocusNode,
                          showMyLocationDefault: widget.showMyLocationDefault,
                          accentColor: AppColors.accentOf(context),
                          onSwapRequested: widget.onSwapRequested,
                          layerLink: widget.routeFieldLink,
                          fromLoading: widget.fromLoading,
                          toLoading: widget.toLoading,
                        ),
                      ),
                    ),
                  ),

                  // Time and Search actions (expanded only)
                  if (!widget.isCollapsed)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      child: Builder(
                        builder: (context) {
                          const double start =
                              0.5; // begin sliding near mid-drag
                          final double raw =
                              (widget.collapseProgress - start) / (1 - start);
                          final double t = raw.clamp(0.0, 1.0);
                          final double dy = 16.0 * t; // slight slide 0..16 px
                          return GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: widget.onUnfocus,
                            child: Transform.translate(
                              offset: Offset(0, dy),
                              child: Row(
                                children: [
                                  GestureDetector(
                                    // Block parent GestureDetector from triggering unfocus
                                    // This prevents flickering when tapping the time button
                                    onTap: () {
                                      // Consume the event - button handles its own tap
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: CompositedTransformTarget(
                                      link: widget.timeSelectionLayerLink,
                                      child: PillButton(
                                        onTap: widget.onTimeSelectionTap,
                                        onTapDown:
                                            widget.onTimeSelectionTapDown,
                                        onTapCancel:
                                            widget.onTimeSelectionTapCancel,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              LucideIcons.clock,
                                              size: 16,
                                              color: AppColors.black,
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              widget.timeSelection
                                                  .toDisplayString(),
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
                                  ),
                                  const Spacer(),
                                  // Search button (primary)
                                  GestureDetector(
                                    // Block parent GestureDetector from interfering
                                    onTap: () {
                                      // Consume the event - button handles its own tap
                                    },
                                    behavior: HitTestBehavior.opaque,
                                    child: PrimaryButton(
                                      onTap: () =>
                                          widget.onSearch(widget.timeSelection),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Text(
                                            'Search',
                                            style: TextStyle(
                                              color: AppColors.solidWhite,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                  // Scrollable content for favourites and recents
                  if (!widget.isCollapsed)
                    Expanded(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.translucent,
                                  onTap: widget.onUnfocus,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Favourites',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.black,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      if (widget.favorites.isEmpty)
                                        const _FavoritesEmptyMessage()
                                      else
                                        _FavoritesQuickActions(
                                          favorites: widget.favorites,
                                          onFavoriteTap: widget.onFavoriteTap,
                                          hasLocationPermission:
                                              widget.hasLocationPermission,
                                        ),
                                    ],
                                  ),
                                ),
                              ),

                              // Recent trips section
                              if (widget.recentTrips.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 16),
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.translucent,
                                    onTap: widget.onUnfocus,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Recent trips',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                            color: AppColors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        ...widget.recentTrips.map(
                                          (trip) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 16,
                                            ),
                                            child: _RecentTripTile(
                                              trip: trip,
                                              onTap: () =>
                                                  widget.onRecentTripTap(trip),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Add padding to account for floating nav bar
                              const SizedBox(height: 96),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PillButton extends StatefulWidget {
  const PillButton({
    super.key,
    required this.onTap,
    required this.child,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.restingColor,
    this.pressedColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.borderColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });
  final VoidCallback onTap;
  final VoidCallback? onTapDown;
  final VoidCallback? onTapUp;
  final VoidCallback? onTapCancel;
  final Widget child;
  final Color? restingColor;
  final Color? pressedColor;
  final BorderRadius borderRadius;
  final Color? borderColor;
  final EdgeInsetsGeometry padding;
  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    final restingColor =
        widget.restingColor ?? AppColors.black.withValues(alpha: 0.06);
    final pressedColor =
        widget.pressedColor ?? AppColors.black.withValues(alpha: 0.08);
    final borderColor =
        widget.borderColor ?? AppColors.black.withValues(alpha: 0.07);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) {
        widget.onTapDown?.call();
        setState(() => _pressed = true);
      },
      onTapUp: (_) {
        widget.onTapUp?.call();
        setState(() => _pressed = false);
      },
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
            color: _pressed ? pressedColor : restingColor,
            border: Border.all(color: borderColor),
            borderRadius: widget.borderRadius,
          ),
          padding: widget.padding,
          child: widget.child,
        ),
      ),
    );
  }
}

class PrimaryButton extends StatefulWidget {
  const PrimaryButton({super.key, required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;
  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
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
          child: widget.child,
        ),
      ),
    );
  }
}

class _RecentTripTile extends StatefulWidget {
  const _RecentTripTile({required this.trip, required this.onTap});

  final TripHistoryItem trip;
  final VoidCallback onTap;

  @override
  State<_RecentTripTile> createState() => _RecentTripTileState();
}

class _RecentTripTileState extends State<_RecentTripTile> {
  bool _isLoading = false;

  void _handleTap() async {
    if (_isLoading) return; // Prevent multiple clicks

    setState(() => _isLoading = true);

    // Call the onTap callback
    widget.onTap();

    // Reset loading state after a delay (navigation will have happened by then)
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppColors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: AppColors.black.withValues(alpha: 0.07),
            ),
          ),
          alignment: Alignment.center,
          child: Icon(
            LucideIcons.route,
            size: 18,
            color: AppColors.black,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.trip.fromName,
                style: TextStyle(
                  color: AppColors.black,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Icon(
                    LucideIcons.chevronRight,
                    size: 14,
                    color: AppColors.black.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.trip.toName,
                      style: TextStyle(
                        color: AppColors.black.withValues(alpha: 0.6),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _handleTap,
      child: _isLoading
          ? Shimmer.fromColors(
              baseColor: const Color(0x1A000000),
              highlightColor: const Color(0x0D000000),
              child: content,
            )
          : content,
    );
  }
}

class _FavoritesQuickActions extends StatelessWidget {
  const _FavoritesQuickActions({
    required this.favorites,
    required this.onFavoriteTap,
    required this.hasLocationPermission,
  });

  final List<FavoritePlace> favorites;
  final ValueChanged<FavoritePlace> onFavoriteTap;
  final bool hasLocationPermission;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          const SizedBox(width: 12),
          for (final favorite in favorites) ...[
            _FavoriteShortcut(
              favorite: favorite,
              enabled: hasLocationPermission,
              onTap: () => onFavoriteTap(favorite),
            ),
            const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _FavoriteShortcut extends StatelessWidget {
  const _FavoriteShortcut({
    required this.favorite,
    required this.enabled,
    required this.onTap,
  });

  final FavoritePlace favorite;
  final bool enabled;
  final VoidCallback onTap;

  IconData _getIconData(String iconName) {
    const iconMap = {
      'mapPin': LucideIcons.mapPin,
      'home': LucideIcons.house,
      'briefcase': LucideIcons.briefcase,
      'school': LucideIcons.school,
      'shoppingBag': LucideIcons.shoppingBag,
      'coffee': LucideIcons.coffee,
      'utensils': LucideIcons.utensils,
      'dumbbell': LucideIcons.dumbbell,
      'heart': LucideIcons.heart,
      'star': LucideIcons.star,
      'music': LucideIcons.music,
      'plane': LucideIcons.plane,
    };
    return iconMap[iconName] ?? LucideIcons.mapPin;
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final textColor =
        enabled ? AppColors.black : AppColors.black.withValues(alpha: 0.6);

    return Opacity(
      opacity: enabled ? 1.0 : 0.6,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: enabled ? onTap : null,
        child: Container(
          width: 96,
          height: 96,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x11000000)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: enabled ? 0.12 : 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _getIconData(favorite.iconName),
                  size: 22,
                  color: enabled ? accent : accent.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                favorite.name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: textColor,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FavoritesEmptyMessage extends StatelessWidget {
  const _FavoritesEmptyMessage();

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(LucideIcons.heart, size: 24, color: accent),
          ),
          const SizedBox(height: 12),
          Text(
            'No favourites yet',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Add your go-to destinations for quick routing.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.black.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
