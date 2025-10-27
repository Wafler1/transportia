import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../screens/itinerary_list_screen.dart';
import '../services/location_service.dart';
import '../services/transitous_geocode_service.dart';
import '../widgets/route_field_box.dart';
import '../widgets/validation_toast.dart';
import '../utils/haptics.dart';
import '../theme/app_colors.dart';

class BottomCard extends StatelessWidget {
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
        onTap: onUnfocus,
        child: Listener(
          onPointerDown: (_) => onUnfocus(),
          child: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle area
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onHandleTap,
                  onVerticalDragStart: (_) => onDragStart(),
                  onVerticalDragUpdate: (d) => onDragUpdate(d.delta.dy),
                  onVerticalDragEnd: (d) =>
                      onDragEnd(d.velocity.pixelsPerSecond.dy),
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
                    final t = ((collapseProgress - fadeStart) / (1 - fadeStart))
                        .clamp(0.0, 1.0);
                    final opacity = 1.0 - Curves.easeOut.transform(t);
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onTap: onUnfocus,
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
                    fromController: fromCtrl,
                    toController: toCtrl,
                    fromFocusNode: fromFocusNode,
                    toFocusNode: toFocusNode,
                    showMyLocationDefault: showMyLocationDefault,
                    accentColor: AppColors.accent,
                    onSwapRequested: onSwapRequested,
                    layerLink: routeFieldLink,
                    fromLoading: fromLoading,
                    toLoading: toLoading,
                  ),
                ),

                // Time and Search actions (expanded only)
                if (!isCollapsed)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    child: Builder(
                      builder: (context) {
                        const double start = 0.5; // begin sliding near mid-drag
                        final double raw =
                            (collapseProgress - start) / (1 - start);
                        final double t = raw.clamp(0.0, 1.0);
                        final double dy = 16.0 * t; // slight slide 0..16 px
                        return GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: onUnfocus,
                          child: Transform.translate(
                            offset: Offset(0, dy),
                            child: Row(
                              children: [
                                // Time selector (placeholder UI)
                                PillButton(
                                  onTap: () {
                                    onUnfocus();
                                  },
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(
                                        LucideIcons.clock,
                                        size: 16,
                                        color: AppColors.black,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Now',
                                        style: TextStyle(
                                          color: AppColors.black,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Search button (primary)
                                PrimaryButton(
                                  onTap: () async {
                                    onUnfocus();
                                    final needsFrom = !showMyLocationDefault;
                                    final fromEmpty = fromCtrl.text
                                        .trim()
                                        .isEmpty;
                                    final toEmpty = toCtrl.text.trim().isEmpty;
                                    final invalid =
                                        (needsFrom && fromEmpty) || toEmpty;
                                    if (invalid) {
                                      final msg = showMyLocationDefault
                                          ? 'Please enter a destination'
                                          : 'Please enter both locations';
                                      showValidationToast(context, msg);
                                      return;
                                    }
                                    Haptics.mediumTick();

                                    double? fromLat, fromLon, toLat, toLon;

                                    if (fromSelection != null) {
                                      fromLat = fromSelection!.lat;
                                      fromLon = fromSelection!.lon;
                                    } else {
                                      final location = await LocationService.currentPosition();
                                      fromLat = location.latitude;
                                      fromLon = location.longitude;
                                    }

                                    if (toSelection != null) {
                                      toLat = toSelection!.lat;
                                      toLon = toSelection!.lon;
                                    } else {
                                      showValidationToast(context, 'Please select a destination');
                                      return;
                                    }

                                    Navigator.of(context).push(CupertinoPageRoute(
                                      builder: (_) => ItineraryListScreen(
                                        fromLat: fromLat!,
                                        fromLon: fromLon!,
                                        toLat: toLat!,
                                        toLon: toLon!,
                                      ),
                                    )).then((_) => onUnfocus());
                                  },
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
