import 'package:flutter/widgets.dart';

import '../../theme/app_colors.dart';

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
