import 'package:flutter/widgets.dart';
import '../utils/haptics.dart';
import '../theme/app_colors.dart';

class PressableHighlight extends StatefulWidget {
  const PressableHighlight({
    super.key,
    required this.onPressed,
    required this.child,
    this.highlightColor,
    this.borderRadius = const BorderRadius.all(Radius.circular(32)),
    this.enableHaptics = true,
  });

  final VoidCallback onPressed;
  final Widget child;
  final Color? highlightColor;
  final BorderRadius borderRadius;
  final bool enableHaptics;

  @override
  State<PressableHighlight> createState() => _PressableHighlightState();
}

class _PressableHighlightState extends State<PressableHighlight> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tint = (widget.highlightColor ?? AppColors.accent).withValues(
      alpha: 0.15,
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (widget.enableHaptics) {
          Haptics.subtlePress();
        }
        widget.onPressed();
      },
      onTapDown: (_) => _setPressed(true),
      onTapUp: (_) => _setPressed(false),
      onTapCancel: () => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: _pressed ? tint : const Color(0x00000000),
          borderRadius: widget.borderRadius,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: widget.child,
      ),
    );
  }
}
