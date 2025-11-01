import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';

class StatisticsScreen extends StatelessWidget {
  const StatisticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Statistics',
              onBackButtonPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.accentOf(context).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: Icon(
                          LucideIcons.construction,
                          size: 50,
                          color: AppColors.accentOf(context),
                        ),
                      ),
                      const SizedBox(height: 32),
                      const Text(
                        'Under Construction',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Travel statistics and insights are coming soon!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0x66000000),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0x05000000),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0x1A000000)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Planned Features:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.black,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _buildFeatureItem(context, 'Total trips and distance traveled'),
                            const SizedBox(height: 12),
                            _buildFeatureItem(context, 'Most visited destinations'),
                            const SizedBox(height: 12),
                            _buildFeatureItem(context, 'Transportation mode breakdowns'),
                            const SizedBox(height: 12),
                            _buildFeatureItem(context, 'Travel time and cost analytics'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, String text) {
    return Row(
      children: [
        Icon(
          LucideIcons.check,
          size: 18,
          color: AppColors.accentOf(context),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0x99000000),
            ),
          ),
        ),
      ],
    );
  }
}
