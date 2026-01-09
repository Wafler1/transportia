import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

class ErrorNotice extends StatelessWidget {
  const ErrorNotice({super.key, required this.message, this.compact = false});

  final String message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
        : const EdgeInsets.all(16);
    final radius = BorderRadius.circular(compact ? 12 : 16);
    final iconSize = compact ? 18.0 : 22.0;
    final fontSize = compact ? 13.0 : 15.0;
    final spacing = compact ? 6.0 : 8.0;

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.black.withValues(alpha: 0.04),
        borderRadius: radius,
        border: Border.all(color: AppColors.black.withValues(alpha: 0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.triangleAlert, size: iconSize, color: accent),
          SizedBox(height: spacing),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: AppColors.black.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}
