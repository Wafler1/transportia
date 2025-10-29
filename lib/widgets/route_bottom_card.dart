import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../models/time_selection.dart';
import '../models/trip_history_item.dart';
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
    required this.timeSelection,
    required this.recentTrips,
    required this.onRecentTripTap,
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
  final TimeSelection timeSelection;
  final List<TripHistoryItem> recentTrips;
  final ValueChanged<TripHistoryItem> onRecentTripTap;
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
        onTap: widget.onUnfocus,
        child: Listener(
          onPointerDown: (_) => widget.onUnfocus(),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle area
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: widget.onHandleTap,
                  onVerticalDragStart: (_) => widget.onDragStart(),
                  onVerticalDragUpdate: (d) => widget.onDragUpdate(d.delta.dy),
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
                          color: const Color(0x33000000),
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
                    final t = ((widget.collapseProgress - fadeStart) / (1 - fadeStart))
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
                            child: const Padding(
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
                  child: RouteFieldBox(
                    fromController: widget.fromCtrl,
                    toController: widget.toCtrl,
                    fromFocusNode: widget.fromFocusNode,
                    toFocusNode: widget.toFocusNode,
                    showMyLocationDefault: widget.showMyLocationDefault,
                    accentColor: AppColors.accent,
                    onSwapRequested: widget.onSwapRequested,
                    layerLink: widget.routeFieldLink,
                    fromLoading: widget.fromLoading,
                    toLoading: widget.toLoading,
                  ),
                ),

                // Time and Search actions (expanded only)
                if (!widget.isCollapsed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Builder(
                      builder: (context) {
                        const double start = 0.5; // begin sliding near mid-drag
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
                                CompositedTransformTarget(
                                  link: widget.timeSelectionLayerLink,
                                  child: PillButton(
                                    onTap: widget.onTimeSelectionTap,
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
                                const Spacer(),
                                // Search button (primary)
                                PrimaryButton(
                                  onTap: () => widget.onSearch(widget.timeSelection),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Text(
                                        'Search',
                                        style: TextStyle(
                                          color: AppColors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                // Favourites section (placeholder, expanded only)
                if (!widget.isCollapsed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: widget.onUnfocus,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Favourites',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                          ),
                          SizedBox(height: 16),
                          Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Text(
                                'No favourites yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0x66000000),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // Recent trips section (expanded only)
                if (!widget.isCollapsed && widget.recentTrips.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    child: GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: widget.onUnfocus,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Recent trips',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...widget.recentTrips.map((trip) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: _RecentTripTile(
                                  trip: trip,
                                  onTap: () => widget.onRecentTripTap(trip),
                                ),
                              )),
                        ],
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


class PillButton extends StatefulWidget {
  const PillButton({
    super.key,
    required this.onTap,
    required this.child,
    this.restingColor = const Color(0x0F000000),
    this.pressedColor = const Color(0x14000000),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.borderColor = const Color(0x11000000),
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });
  final VoidCallback onTap;
  final Widget child;
  final Color restingColor;
  final Color pressedColor;
  final BorderRadius borderRadius;
  final Color borderColor;
  final EdgeInsetsGeometry padding;
  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
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
            color: _pressed ? widget.pressedColor : widget.restingColor,
            border: Border.all(color: widget.borderColor),
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
                ? const Color.fromARGB(255, 0, 105, 124)
                : AppColors.accent,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: widget.child,
        ),
      ),
    );
  }
}

class _RecentTripTile extends StatelessWidget {
  const _RecentTripTile({required this.trip, required this.onTap});

  final TripHistoryItem trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0x0F000000),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0x11000000)),
            ),
            alignment: Alignment.center,
            child: const Icon(
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
                  trip.fromName,
                  style: const TextStyle(
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
                    const Icon(
                      LucideIcons.chevronRight,
                      size: 14,
                      color: Color(0x99000000),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        trip.toName,
                        style: const TextStyle(
                          color: Color(0x99000000),
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
      ),
    );
  }
}
