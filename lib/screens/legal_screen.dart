import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/validation_toast.dart';

class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key});

  Future<void> _openUrl(BuildContext context, String url) async {
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (context.mounted) {
        showValidationToast(context, "Unable to open link.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Legal',
              onBackButtonPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Center(
                      child: Column(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              color: AppColors.accentOf(context).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              LucideIcons.scale,
                              size: 36,
                              color: AppColors.accentOf(context),
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Legal Information',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: AppColors.black,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Om nom nom nom 🍪',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Color(0x66000000),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Terms of Service
                    _buildLegalCard(
                      context: context,
                      icon: LucideIcons.fileText,
                      title: 'Terms of Service',
                      description: 'Review our terms and conditions for using Entaria',
                      url: 'https://wafler.one/entaria/terms',
                      onTap: () => _openUrl(context, 'https://wafler.one/entaria/terms'),
                    ),

                    const SizedBox(height: 12),

                    // Privacy Policy
                    _buildLegalCard(
                      context: context,
                      icon: LucideIcons.shieldCheck,
                      title: 'Privacy Policy',
                      description: 'Learn how we collect, use, and protect your data',
                      url: 'https://wafler.one/entaria/privacy',
                      onTap: () => _openUrl(context, 'https://wafler.one/entaria/privacy'),
                    ),

                    const SizedBox(height: 32),

                    // Data Usage section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0x05000000),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0x0A000000)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                LucideIcons.database,
                                size: 20,
                                color: AppColors.accentOf(context),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Data We Collect',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.black,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildDataItem('That\'s the best part, we don\'t!', context),
                          _buildDataItem('Third-party services may collect data as per their policies', context),
                          _buildDataItem('For more details, refer to our Privacy Policy', context),
                          const SizedBox(height: 8),
                          Text(
                            'We never sell your data to third parties.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.accentOf(context),
                            ),
                          ),

                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Footer
                    Center(
                      child: Column(
                        children: [
                          const Text(
                            'Last updated: January 2025',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0x66000000),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '© 2025 Wafler.one. All rights reserved.',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0x66000000),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegalCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required String url,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x1A000000)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.accentOf(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 24,
                color: AppColors.accentOf(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0x66000000),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.externalLink,
              size: 20,
              color: AppColors.accentOf(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataItem(String text, BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.accent,
              fontWeight: FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0x80000000),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
