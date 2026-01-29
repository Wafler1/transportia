import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    this.padding = EdgeInsets.zero,
    this.titleStyle,
    this.subtitleStyle,
    this.textAlign = TextAlign.center,
    this.spacing = 8,
    this.iconSpacing = 24,
  });

  final String title;
  final String? subtitle;
  final Widget? icon;
  final EdgeInsetsGeometry padding;
  final TextStyle? titleStyle;
  final TextStyle? subtitleStyle;
  final TextAlign textAlign;
  final double spacing;
  final double iconSpacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[icon!, SizedBox(height: iconSpacing)],
          Text(
            title,
            textAlign: textAlign,
            style:
                titleStyle ??
                TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.black,
                ),
          ),
          if (subtitle != null) ...[
            SizedBox(height: spacing),
            Text(
              subtitle!,
              textAlign: textAlign,
              style:
                  subtitleStyle ??
                  TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.black.withValues(alpha: 0.4),
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
