import 'dart:ui';
import 'package:entaria_app/screens/appearance_screen.dart';
import 'package:entaria_app/screens/statistics_screen.dart';
import 'package:entaria_app/screens/favourites_screen.dart';
import 'package:entaria_app/screens/info_screen.dart';
import 'package:entaria_app/screens/legal_screen.dart';
import 'package:entaria_app/screens/location_settings_screen.dart';
import 'package:entaria_app/utils/custom_page_route.dart';
import 'package:entaria_app/widgets/validation_toast.dart';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_colors.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.accentOf(context).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        LucideIcons.user,
                        size: 24,
                        color: AppColors.accentOf(context),
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'User',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Settings & Information',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: Color(0x66000000),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Sponsored by Wafler.one banner with orange shadow
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: GestureDetector(
                  onTap: () async {
                    try {
                      final uri = Uri.parse('http://wafler.one?ref=entaria');
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    } catch (e) {
                      showValidationToast(context, "Unable to open link.");
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0x1A000000)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x20FC970A),
                          blurRadius: 10,
                          offset: Offset(0, 4),
                          spreadRadius: 1,
                        ),
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 12,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFC970A).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            LucideIcons.sparkles,
                            size: 22,
                            color: Color(0xFFFC970A),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Created by ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0x80000000),
                                    ),
                                  ),
                                  const Text(
                                    'Wafler.one',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFC970A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Helping you travel smarter',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0x66000000),
                                  height: 1.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Statistics section
              _buildSection(
                title: 'Analytics',
                items: [
                  _SettingsItem(
                    icon: LucideIcons.chartPie,
                    title: 'Statistics',
                    subtitle: 'View your travel statistics',
                    onTap: () {
                      Navigator.of(context).push(CustomPageRoute(
                        child: const StatisticsScreen(),
                      ));
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Settings sections
              _buildSection(
                title: 'Preferences',
                items: [
                  _SettingsItem(
                    icon: LucideIcons.heart,
                    title: 'Favourites',
                    subtitle: 'Manage your favourite places',
                    onTap: () {
                      Navigator.of(context).push(CustomPageRoute(
                        child: const FavouritesScreen(),
                      ));
                    },
                  ),
                  _SettingsItem(
                    icon: LucideIcons.mapPin,
                    title: 'Location',
                    subtitle: 'Location permissions',
                    onTap: () {
                      Navigator.of(context).push(CustomPageRoute(
                        child: const LocationSettingsScreen(),
                      ));
                    },
                  ),
                  _SettingsItem(
                    icon: LucideIcons.palette,
                    title: 'Appearance',
                    subtitle: 'Theme and display',
                    onTap: () {
                      Navigator.of(context).push(CustomPageRoute(
                        child: const AppearanceScreen(),
                      ));
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _buildSection(
                title: 'About',
                items: [
                  _SettingsItem(
                    icon: LucideIcons.info,
                    title: 'About Entaria',
                    subtitle: 'About, credits, and more',
                    onTap: () {
                      Navigator.of(context).push(CustomPageRoute(
                        child: const InfoScreen(),
                      ));
                    },
                  ),
                  _SettingsItem(
                    icon: LucideIcons.scale,
                    title: 'Legal',
                    subtitle: 'Privacy policy and terms of service',
                    onTap: () {
                      Navigator.of(context).push(CustomPageRoute(
                        child: const LegalScreen(),
                      ));
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // App version footer
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0x0A000000),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        LucideIcons.trainFront,
                        size: 24,
                        color: Color(0x33000000),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Entaria',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Version 1.0.0',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0x66000000),
                      ),
                    ),
                    // Add extra padding to account for floating nav bar
                    const SizedBox(height: 112),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required List<_SettingsItem> items,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0x66000000),
                letterSpacing: 0.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0x05000000),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x0A000000)),
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  items[i],
                  if (i < items.length - 1)
                    const Padding(
                      padding: EdgeInsets.only(left: 60),
                      /* child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Color(0x0A000000),
                      ), */
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatefulWidget {
  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  State<_SettingsItem> createState() => _SettingsItemState();
}

class _SettingsItemState extends State<_SettingsItem> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        decoration: BoxDecoration(
          color: _pressed
              ? const Color(0x08000000)
              : const Color(0x00000000),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentOf(context).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.icon,
                size: 22,
                color: AppColors.accentOf(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0x66000000),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              LucideIcons.chevronRight,
              size: 20,
              color: Color(0x33000000),
            ),
          ],
        ),
      ),
    );
  }
}
