import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import '../widgets/app_icon_header.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/section_title.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return AppPageScaffold(
      title: 'About Entaria',
      scrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AppIconHeader(
            icon: LucideIcons.info,
            title: 'Entaria',
            subtitle: 'Version 1.0.1',
            iconSize: 40,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
          const SectionTitle(text: 'Our Purpose'),
          const SizedBox(height: 12),
          _buildCard(
            child: const Text(
              'Entaria is a modern travel companion designed to make public transportation easier and more accessible. Entaria aims to provide all of this free of charge and utilising only open-source software without sacrificing user privacy.',
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
            'contact@wafler.one',
            LucideIcons.mail,
            'mailto:contact@wafler.one',
          ),
          _buildContactItem(
            context,
            'Website',
            'wafler.one',
            LucideIcons.globe,
            'https://wafler.one?ref=entaria',
          ),
          const SizedBox(height: 24),
          const SectionTitle(text: 'Open Source Credits'),
          const SizedBox(height: 12),
          const Text(
            'Entaria is built with the help of amazing open-source projects and APIs:',
            style: TextStyle(fontSize: 14, color: Color(0x80000000)),
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
          )
        ],
      ),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0x05000000),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x0A000000)),
      ),
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
        } catch (e) {
          // Handle error silently
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0x05000000),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x0A000000)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.accentOf(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppColors.accentOf(context)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
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
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x05000000),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0x0A000000)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.accentOf(context).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: AppColors.accentOf(context)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 2),
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
        ],
      ),
    );
  }
}
