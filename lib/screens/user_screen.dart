import 'dart:async';

import 'package:transportia/screens/appearance_screen.dart';
import 'package:transportia/screens/developer_info_screen.dart';
import 'package:transportia/screens/statistics_screen.dart';
import 'package:transportia/screens/favourites_screen.dart';
import 'package:transportia/screens/info_screen.dart';
import 'package:transportia/screens/legal_screen.dart';
import 'package:transportia/screens/location_settings_screen.dart';
import 'package:transportia/utils/custom_page_route.dart';
import 'package:transportia/screens/transit_options_screen.dart';
import 'package:transportia/widgets/validation_toast.dart';
import 'package:transportia/environment.dart';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/settings_section.dart';
import '../utils/app_version.dart';
import '../widgets/settings_tile.dart';
import '../widgets/icon_badge.dart';
import '../widgets/custom_card.dart';
import '../l10n/app_localizations.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Timer? _debugHoldTimer;
  bool _debugOpened = false;

  @override
  void dispose() {
    _debugHoldTimer?.cancel();
    super.dispose();
  }

  void _startDebugHold() {
    _debugHoldTimer?.cancel();
    _debugOpened = false;
    _debugHoldTimer = Timer(const Duration(seconds: 5), _openDeveloperInfo);
  }

  void _cancelDebugHold() {
    _debugHoldTimer?.cancel();
    _debugHoldTimer = null;
  }

  void _openDeveloperInfo() {
    if (!mounted || _debugOpened) return;
    _debugOpened = true;
    Navigator.of(
      context,
    ).push(CustomPageRoute(child: const DeveloperInfoScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    context.watch<ThemeProvider>();
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                child: Row(
                  children: [
                    IconBadge(
                      icon: LucideIcons.user,
                      size: 48,
                      iconSize: 24,
                      backgroundColor: AppColors.accentOf(
                        context,
                      ).withValues(alpha: 0.12),
                      iconColor: AppColors.accentOf(context),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.screensUserScreensTitleUser,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: AppColors.black,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          l10n.screensUserScreensSubtitleUser,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black.withValues(alpha: 0.4),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: GestureDetector(
                  onTap: () async {
                    try {
                      final uri = Uri.parse(Environment.sponsorUrl);
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      showValidationToast(
                        context,
                        l10n.screensUserScreensUnableToOpenLink,
                      );
                    }
                  },
                  child: CustomCard(
                    margin: EdgeInsets.zero,
                    padding: const EdgeInsets.all(18),
                    borderRadius: BorderRadius.circular(16),
                    borderColor: AppColors.black.withValues(alpha: 0.1),
                    child: Row(
                      children: [
                        const IconBadge(
                          icon: LucideIcons.sparkles,
                          size: 44,
                          iconSize: 22,
                          backgroundColor: Color(0x1FFC970A),
                          iconColor: Color(0xFFFC970A),
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    l10n.screensUserScreensCreatedBy,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.black.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    l10n.screensUserScreensCreatedByCompany,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFFC970A),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                l10n.screensUserScreensCreatedBySlogan,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.black.withValues(alpha: 0.4),
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

              SettingsSection(
                title: l10n.screensUserScreensAnalyticsTitle,
                children: [
                  SettingsTile(
                    icon: LucideIcons.chartPie,
                    title: l10n.screensUserScreensStatisticsTitle,
                    subtitle: l10n.screensUserScreensStatisticsSubtitle,
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).push(CustomPageRoute(child: const StatisticsScreen()));
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SettingsSection(
                title: l10n.screensUserScreensPreferencesTitle,
                children: [
                  SettingsTile(
                    icon: LucideIcons.heart,
                    title: l10n.screensUserScreensFavouritesTitle,
                    subtitle: l10n.screensUserScreensFavouritesSubtitle,
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).push(CustomPageRoute(child: const FavouritesScreen()));
                    },
                  ),
                  SettingsTile(
                    icon: LucideIcons.mapPin,
                    title: l10n.screensUserScreensLocationTitle,
                    subtitle: l10n.screensUserScreensLocationSubtitle,
                    onPressed: () {
                      Navigator.of(context).push(
                        CustomPageRoute(child: const LocationSettingsScreen()),
                      );
                    },
                  ),
                  SettingsTile(
                    icon: LucideIcons.palette,
                    title: l10n.screensUserScreensAppearanceTitle,
                    subtitle: l10n.screensUserScreensAppearanceSubtitle,
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).push(CustomPageRoute(child: const AppearanceScreen()));
                    },
                  ),
                  SettingsTile(
                    icon: LucideIcons.settings2,
                    title: l10n.screensUserScreensTransitOptionsSubtitle,
                    subtitle: l10n.screensUserScreensTransitOptionsSubtitle,
                    onPressed: () {
                      Navigator.of(context).push(
                        CustomPageRoute(child: const TransitOptionsScreen()),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 12),

              SettingsSection(
                title: l10n.screensUserScreensAboutTitle,
                children: [
                  SettingsTile(
                    icon: LucideIcons.info,
                    title: l10n.screensUserScreensAboutAppnameTitle(
                      Environment.appName,
                    ),
                    subtitle: l10n.screensUserScreensAboutSubtitle,
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).push(CustomPageRoute(child: const InfoScreen()));
                    },
                  ),
                  SettingsTile(
                    icon: LucideIcons.scale,
                    title: l10n.screensUserScreensLegalTitle,
                    subtitle: l10n.screensUserScreensLegalSubtitle,
                    onPressed: () {
                      Navigator.of(
                        context,
                      ).push(CustomPageRoute(child: const LegalScreen()));
                    },
                  ),
                ],
              ),

              const SizedBox(height: 32),

              Center(
                child: Column(
                  children: [
                    GestureDetector(
                      onTapDown: (_) => _startDebugHold(),
                      onTapUp: (_) => _cancelDebugHold(),
                      onTapCancel: _cancelDebugHold,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          'assets/branding/logo_rounded_min.png',
                          width: 56,
                          height: 56,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      Environment.appName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.screensUserScreensVersionTitle(AppVersion.current),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.black.withValues(alpha: 0.4),
                      ),
                    ),
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
}
