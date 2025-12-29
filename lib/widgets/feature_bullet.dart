import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';

class FeatureBullet extends StatelessWidget {
  const FeatureBullet({
    super.key,
    required this.label,
    this.icon = LucideIcons.check,
    this.iconColor,
    this.textColor,
  });

  final String label;
  final IconData icon;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final themeTextColor = context.watch<ThemeProvider>().textColor;
    final effectiveIconColor = iconColor ?? AppColors.accentOf(context);
    final effectiveTextColor =
        textColor ?? themeTextColor.withValues(alpha: 0.6);

    return Row(
      children: [
        Icon(icon, size: 18, color: effectiveIconColor),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: effectiveTextColor,
            ),
          ),
        ),
      ],
    );
  }
}
