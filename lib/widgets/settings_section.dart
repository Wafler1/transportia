import 'package:flutter/widgets.dart';
import '../theme/app_colors.dart';

/// Card-like grouping for related settings rows.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.spacing = 0,
  });

  final String title;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.black.withValues(alpha: 0.4),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.black.withValues(alpha: 0.04),
              ),
            ),
            child: Column(
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: EdgeInsets.only(
                        left: 60,
                        bottom: spacing,
                        top: spacing,
                      ),
                      child: SizedBox(
                        height: 1,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: AppColors.black.withValues(alpha: 0.04),
                          ),
                        ),
                      ),
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
