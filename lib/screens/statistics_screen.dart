import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon_header.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/feature_bullet.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return AppPageScaffold(
      title: 'Statistics',
      padding: const EdgeInsets.all(40),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconHeader(
              icon: LucideIcons.construction,
              title: 'Under Construction',
              subtitle: 'Travel statistics and insights are coming soon!',
              iconSize: 50,
              iconColor: AppColors.accentOf(context),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.black.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.black.withValues(alpha: 0.1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Planned Features:',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  FeatureBullet(label: 'Total trips and distance traveled'),
                  const SizedBox(height: 12),
                  const FeatureBullet(label: 'Most visited destinations'),
                  const SizedBox(height: 12),
                  const FeatureBullet(label: 'Transportation mode breakdowns'),
                  const SizedBox(height: 12),
                  const FeatureBullet(label: 'Travel time and cost analytics'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
