import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';
import 'pressable_highlight.dart';

/// Reusable interactive tile for the settings screens.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onPressed,
    this.trailingIcon = LucideIcons.chevronRight,
    this.iconColor,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onPressed;
  final IconData? trailingIcon;
  final Color? iconColor;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final accent = iconColor ?? AppColors.accentOf(context);

    final row = Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 22, color: accent),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.black.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          trailing!,
        ] else if (trailingIcon != null) ...[
          Icon(
            trailingIcon,
            size: 20,
            color: AppColors.black.withValues(alpha: 0.2),
          ),
        ],
      ],
    );

    if (onPressed == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: row,
      );
    }

    return PressableHighlight(
      onPressed: onPressed!,
      enableHaptics: false,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        child: row,
      ),
    );
  }
}
