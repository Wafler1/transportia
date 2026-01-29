import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    this.size = 44,
    this.iconSize = 20,
    this.backgroundColor,
    this.iconColor,
    this.borderRadius,
    this.borderColor,
    this.borderWidth = 1,
  });

  final IconData icon;
  final double size;
  final double iconSize;
  final Color? backgroundColor;
  final Color? iconColor;
  final BorderRadius? borderRadius;
  final Color? borderColor;
  final double borderWidth;

  @override
  Widget build(BuildContext context) {
    final resolvedBackground =
        backgroundColor ?? AppColors.black.withValues(alpha: 0.06);
    final resolvedIconColor = iconColor ?? AppColors.black;
    final resolvedRadius = borderRadius ?? BorderRadius.circular(12);
    final resolvedBorderColor = borderColor;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: resolvedBackground,
        borderRadius: resolvedRadius,
        border: resolvedBorderColor == null
            ? null
            : Border.all(color: resolvedBorderColor, width: borderWidth),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: iconSize, color: resolvedIconColor),
    );
  }
}
