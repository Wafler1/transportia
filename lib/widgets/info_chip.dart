import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.tint,
  });

  final IconData icon;
  final String label;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final themeTextColor = context.watch<ThemeProvider>().textColor;
    final baseColor = tint ?? themeTextColor;
    final iconColor = tint ?? themeTextColor.withValues(alpha: 0.6);
    final textColor = tint ?? themeTextColor.withValues(alpha: 0.8);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: iconColor),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: textColor),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
