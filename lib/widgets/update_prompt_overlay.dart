import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_colors.dart';
import 'pressable_highlight.dart';

class UpdatePromptOverlay extends StatelessWidget {
  const UpdatePromptOverlay({
    super.key,
    required this.remoteVersion,
    required this.localVersion,
    required this.onDismiss,
    required this.onSkipVersion,
  });

  final String remoteVersion;
  final String localVersion;
  final VoidCallback onDismiss;
  final VoidCallback onSkipVersion;

  static final Uri _downloadUri = Uri.parse(
    'https://wafler.one/transportia/download',
  );

  void _handleUpdateTap() {
    unawaited(launchUrl(_downloadUri, mode: LaunchMode.externalApplication));
    onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);

    return Positioned.fill(
      child: ColoredBox(
        color: const Color(0xB3000000),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 28,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Update available',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: AppColors.black,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Version $remoteVersion is available. '
                        'You are currently on $localVersion.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.35,
                          color: AppColors.black.withValues(alpha: 0.8),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'We recommend updating to get the latest fixes '
                        'and improvements.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.35,
                          color: AppColors.black.withValues(alpha: 0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: PressableHighlight(
                            enableHaptics: false,
                            highlightColor: AppColors.solidWhite,
                            borderRadius: BorderRadius.circular(12),
                            onPressed: _handleUpdateTap,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Center(
                                child: Text(
                                  'Download update',
                                  style: TextStyle(
                                    color: AppColors.solidWhite,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          PressableHighlight(
                            onPressed: onDismiss,
                            enableHaptics: false,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Dismiss',
                                  style: TextStyle(fontSize: 16, color: accent),
                                ),
                                const SizedBox(width: 8),
                                Icon(LucideIcons.x, size: 20, color: accent),
                              ],
                            ),
                          ),
                          Container(
                            height: 20,
                            width: 1,
                            color: AppColors.black.withValues(alpha: 0.1),
                          ),
                          PressableHighlight(
                            onPressed: onSkipVersion,
                            enableHaptics: false,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Don\'t show again',
                                  style: TextStyle(fontSize: 16, color: accent),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  LucideIcons.octagonMinus,
                                  size: 20,
                                  color: accent,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
