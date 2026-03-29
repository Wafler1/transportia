import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../environment.dart';
import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../utils/app_version.dart';
import '../widgets/app_icon_header.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/custom_card.dart';
import '../widgets/section_title.dart';
import '../widgets/icon_badge.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appName = Environment.appName;
    context.watch<ThemeProvider>();
    return AppPageScaffold(
      title: 'About $appName',
      scrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconHeader(
            icon: LucideIcons.info,
            title: appName,
            subtitle: 'Version ${AppVersion.current}',
            iconSize: 40,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const SectionTitle(text: 'Our Purpose'),
              const SizedBox(height: 12),
              _buildCard(
                child: Text(
                  '$appName is a modern travel companion designed to make public transportation easier and more accessible. $appName aims to provide all of this free of charge and utilising only open-source software without sacrificing user privacy.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.5,
                    color: AppColors.black,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SectionTitle(text: 'Contact Us'),
              const SizedBox(height: 12),
              _buildContactItem(
                context,
                'Email',
                Environment.contactEmail,
                LucideIcons.mail,
                'mailto:${Environment.contactEmail}',
              ),
              _buildContactItem(
                context,
                'Website',
                'wafler.one',
                LucideIcons.globe,
                Environment.sponsorUrl,
              ),
              const SizedBox(height: 24),
              const SectionTitle(text: 'Open Source Credits'),
              const SizedBox(height: 12),
              Text(
                '$appName is built with the help of amazing open-source projects and APIs:',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black.withValues(alpha: 0.5),
                ),
              ),
              const SizedBox(height: 12),
              _buildCreditItem(
                context,
                'Transitous',
                'Public transit routing service',
                LucideIcons.route,
              ),
              _buildCreditItem(
                context,
                'MapLibre GL',
                'Mapping platform',
                LucideIcons.map,
              ),
              _buildCreditItem(
                context,
                'Lucide Icons',
                'Icon library',
                LucideIcons.palette,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return CustomCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      backgroundColor: const Color(0x05000000),
      borderColor: const Color(0x0A000000),
      child: child,
    );
  }

  Widget _buildContactItem(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    String url,
  ) {
    return GestureDetector(
      onTap: () async {
        try {
          final uri = Uri.parse(url);
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (e) {}
      },
      child: CustomCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        borderRadius: BorderRadius.circular(8),
        backgroundColor: const Color(0x05000000),
        borderColor: const Color(0x0A000000),
        child: Row(
          children: [
            IconBadge(
              icon: icon,
              size: 36,
              iconSize: 18,
              backgroundColor: AppColors.accentOf(
                context,
              ).withValues(alpha: 0.12),
              iconColor: AppColors.accentOf(context),
              borderRadius: BorderRadius.circular(8),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              LucideIcons.externalLink,
              size: 16,
              color: AppColors.accentOf(context).withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCreditItem(
    BuildContext context,
    String name,
    String description,
    IconData icon,
  ) {
    return CustomCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      borderRadius: BorderRadius.circular(8),
      backgroundColor: AppColors.black.withValues(alpha: 0.02),
      borderColor: AppColors.black.withValues(alpha: 0.04),
      child: Row(
        children: [
          IconBadge(
            icon: icon,
            size: 36,
            iconSize: 18,
            backgroundColor: AppColors.accentOf(
              context,
            ).withValues(alpha: 0.12),
            iconColor: AppColors.accentOf(context),
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.black.withValues(alpha: 0.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
