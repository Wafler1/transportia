import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.accent,
                            AppColors.accent.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        LucideIcons.user,
                        size: 32,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Account',
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

              // Settings sections
              _buildSection(
                title: 'Preferences',
                items: [
                  _SettingsItem(
                    icon: LucideIcons.bell,
                    title: 'Notifications',
                    subtitle: 'Manage your notifications',
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: LucideIcons.mapPin,
                    title: 'Location',
                    subtitle: 'Location permissions',
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: LucideIcons.palette,
                    title: 'Appearance',
                    subtitle: 'Theme and display',
                    onTap: () {},
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
                    subtitle: 'Version, credits, and more',
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: LucideIcons.shield,
                    title: 'Privacy Policy',
                    subtitle: 'How we protect your data',
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: LucideIcons.fileText,
                    title: 'Terms of Service',
                    subtitle: 'Terms and conditions',
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: LucideIcons.heart,
                    title: 'Support Development',
                    subtitle: 'Help keep Entaria free',
                    onTap: () {},
                  ),
                ],
              ),

              const SizedBox(height: 12),

              _buildSection(
                title: 'Help',
                items: [
                  _SettingsItem(
                    icon: LucideIcons.circleQuestionMark,
                    title: 'Help Center',
                    subtitle: 'FAQs and guides',
                    onTap: () {},
                  ),
                  _SettingsItem(
                    icon: LucideIcons.messageCircle,
                    title: 'Contact Us',
                    subtitle: 'Get in touch',
                    onTap: () {},
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
                    // Add extra padding to account for floating nav bar (64px + 16px padding + 16px buffer = 96px)
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
                color: AppColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                widget.icon,
                size: 22,
                color: AppColors.accent,
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
