import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/feature_bullet.dart';

class AccountTabScreen extends StatelessWidget {
  const AccountTabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Account',
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
                          color: AppColors.accentOf(
                            context,
                          ).withValues(alpha: 0.12),
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
                        'Account management features are coming soon!',
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
                            FeatureBullet(
                              label: 'User profiles and authentication',
                            ),
                            const SizedBox(height: 12),
                            FeatureBullet(
                              label: 'Travel history and statistics',
                            ),
                            const SizedBox(height: 12),
                            const FeatureBullet(label: 'Sync across devices'),
                            const SizedBox(height: 12),
                            FeatureBullet(
                              label: 'Personalized recommendations',
                            ),
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
}
