import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';
import '../widgets/pressable_highlight.dart';

/// A reusable button widget for loading more items.
///
/// Displays a loading shimmer when [isLoading] is true, otherwise shows the
/// "Load more" label with a chevron icon. Tapping while loading does nothing.
class LoadMoreButton extends StatelessWidget {
  const LoadMoreButton({
    required this.onTap,
    required this.isLoading,
    super.key,
  });

  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      alignment: Alignment.center,
      child: PressableHighlight(
        onPressed: isLoading ? () {} : onTap,
        enableHaptics: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isLoading) ...[
              // Loading shimmer placeholder
              IgnorePointer(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Shimmer.fromColors(
                    baseColor: const Color(0xFFE2E7EC),
                    highlightColor: const Color(0xFFF7F9FC),
                    period: const Duration(milliseconds: 1100),
                    child: Container(
                      constraints: const BoxConstraints(
                        maxWidth: 120,
                        minWidth: 96,
                      ),
                      height: 20,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E7EC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              Text(
                "Load more",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.accentOf(context),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.chevronDown,
                size: 20,
                color: AppColors.accentOf(context),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
