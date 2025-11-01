import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

/// Consistent hero/header used across multiple preference/info screens.
class AppIconHeader extends StatelessWidget {
  const AppIconHeader({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    this.backgroundColor,
    this.iconSize = 36,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final Color? backgroundColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? AppColors.accentOf(context);
    final badgeBackground = backgroundColor ?? accent.withValues(alpha: 0.12);

    return Column(
      children: [
        Container(
          width: iconSize * 2,
          height: iconSize * 2,
          decoration: BoxDecoration(
            color: badgeBackground,
            borderRadius: BorderRadius.circular(iconSize * 0.5),
          ),
          child: Icon(icon, size: iconSize, color: accent),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColors.black,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: Color(0x66000000),
            ),
          ),
        ],
      ],
    );
  }
}
