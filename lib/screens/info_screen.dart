import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/version_service.dart';
import '../theme/app_colors.dart';
import '../utils/app_version.dart';
import '../utils/version_utils.dart';
import '../widgets/app_icon_header.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/pressable_highlight.dart';
import '../widgets/section_title.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  static final Uri _downloadUri = Uri.parse('https://entaria.net/app/download');

  String? _remoteVersion;
  bool _fetchAttempted = false;

  bool get _showUpdateBanner {
    if (!_fetchAttempted || _remoteVersion == null) {
      return false;
    }
    return isVersionGreater(_remoteVersion!, AppVersion.current);
  }

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    final latest = await VersionService.fetchLatestVersion();
    if (!mounted) return;
    setState(() {
      _remoteVersion = latest;
      _fetchAttempted = true;
    });
  }

  Future<void> _openDownload() async {
    await launchUrl(_downloadUri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    return AppPageScaffold(
      title: 'About Entaria',
      scrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconHeader(
            icon: LucideIcons.info,
            title: 'Entaria',
            subtitle: 'Version ${AppVersion.current}',
            iconSize: 40,
          ),
          if (_showUpdateBanner) ...[
            const SizedBox(height: 16),
            _buildUpdateBanner(context),
          ],
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
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateBanner(BuildContext context) {
    final latest = _remoteVersion ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.accentOf(context).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.accentOf(context).withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Update available',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.accentOf(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Version $latest is ready to download. '
            'Tap below to grab the update.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Color(0xCC000000),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.bottomRight,
            child: PressableHighlight(
              onPressed: _openDownload,
              enableHaptics: false,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Download update',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentOf(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.externalLink,
                    size: 16,
                    color: AppColors.accentOf(context),
                  ),
                ],
              ),
            ),
          ),
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
