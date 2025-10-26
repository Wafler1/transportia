import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Search button (primary)
                                PrimaryButton(
                                  onTap: () {
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
                                    // TODO: Implement actual search action
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

                // Suggestions only when expanded
                if (!isCollapsed) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'Suggestions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _SuggestionsList(
                        items: const [
                          _Suggestion(
                            icon: LucideIcons.house,
                            title: 'Home',
                            subtitle: 'Save your home',
                          ),
                          _Suggestion(
                            icon: LucideIcons.building,
                            title: 'Work',
                            subtitle: 'Save your workplace',
                          ),
                          _Suggestion(
                            icon: LucideIcons.mapPin,
                            title: 'Recent: Café',
                            subtitle: 'Old Town, 1.2 km',
                          ),
                          _Suggestion(
                            icon: LucideIcons.mapPin,
                            title: 'Recent: Station',
                            subtitle: 'Central Station',
                          ),
                        ],
                        onItemTap: onUnfocus,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PillButton extends StatefulWidget {
  const PillButton({super.key, required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;
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
            color: _pressed ? const Color(0x14000000) : const Color(0x0F000000),
            border: Border.all(color: const Color(0x11000000)),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

class _Suggestion {
  final IconData icon;
  final String title;
  final String subtitle;
  const _Suggestion({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

class _SuggestionsList extends StatelessWidget {
  const _SuggestionsList({required this.items, required this.onItemTap});
  final List<_Suggestion> items;
  final VoidCallback onItemTap;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final it = items[index];
        return _SuggestionTile(item: it, onTap: onItemTap);
      },
    );
  }
}

class _SuggestionTile extends StatelessWidget {
  const _SuggestionTile({required this.item, required this.onTap});
  final _Suggestion item;
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
            child: Icon(item.icon, size: 18, color: AppColors.black),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: const TextStyle(
                    color: AppColors.black,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.subtitle,
                  style: const TextStyle(
                    color: Color(0x99000000),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
