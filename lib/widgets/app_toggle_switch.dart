import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

class AppToggleSwitch extends StatefulWidget {
  const AppToggleSwitch({
    super.key,
    required this.value,
    this.onChanged,
    this.width = 30,
    this.height = 16,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final double width;
  final double height;

  @override
  State<AppToggleSwitch> createState() => _AppToggleSwitchState();
}

class _AppToggleSwitchState extends State<AppToggleSwitch> {
  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final isInteractive = widget.onChanged != null;
    final trackColor = widget.value
        ? accent
        : AppColors.black.withValues(alpha: 0.14);
    final borderColor = widget.value
        ? accent.withValues(alpha: 0.7)
        : AppColors.black.withValues(alpha: 0.14);
    final knobSize = widget.height - 4;

    return Semantics(
      button: isInteractive,
      enabled: isInteractive,
      toggled: widget.value,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isInteractive
            ? () => widget.onChanged?.call(!widget.value)
            : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: widget.width,
          height: widget.height,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: borderColor),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: widget.value
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Container(
              width: knobSize,
              height: knobSize,
              decoration: BoxDecoration(
                color: AppColors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.black.withValues(alpha: 0.16),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
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
