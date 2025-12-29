import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';

class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.visibility,
  });

  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final double visibility; // 0.0 (hidden) to 1.0 (visible)

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    final opacity = visibility.clamp(0.0, 1.0);
    final translateY = (1 - opacity) * 32; // Slide down 32px when hiding
    final blur = (1 - opacity) * 8.0; // Blur when fading out
    final scale =
        0.92 + (opacity * 0.08); // Shrink from 1.0 to 0.92 when hiding

    return IgnorePointer(
      ignoring: opacity < 0.1,
      child: Opacity(
        opacity: opacity,
        child: Transform.translate(
          offset: Offset(0, translateY),
          child: Transform.scale(
            scale: scale,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
              child: Padding(
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
                child: Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.black.withValues(alpha: 0.1),
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F000000),
                        blurRadius: 24,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _NavBarItem(
                        icon: LucideIcons.mapPinned,
                        isSelected: currentIndex == 0,
                        onTap: () => onIndexChanged(0),
                      ),
                      _NavBarItem(
                        icon: LucideIcons.clock,
                        isSelected: currentIndex == 1,
                        onTap: () => onIndexChanged(1),
                      ),
                      _NavBarItem(
                        icon: LucideIcons.user,
                        isSelected: currentIndex == 2,
                        onTap: () => onIndexChanged(2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatefulWidget {
  const _NavBarItem({
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  State<_NavBarItem> createState() => _NavBarItemState();
}

class _NavBarItemState extends State<_NavBarItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          duration: const Duration(milliseconds: 100),
          scale: _pressed ? 0.92 : 1.0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? AppColors.accentOf(context).withValues(alpha: 0.12)
                      : const Color(0x00000000),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  widget.icon,
                  size: 24,
                  color: widget.isSelected
                      ? AppColors.accentOf(context)
                      : AppColors.black.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
