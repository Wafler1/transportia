import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon_header.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/app_toggle_switch.dart';
import '../widgets/section_title.dart';
import '../widgets/settings_tile.dart';

class AdvancedSettingsScreen extends StatelessWidget {
  const AdvancedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final showGtfsFields = context.watch<ThemeProvider>().showGtfsFields;

    return AppPageScaffold(
      title: 'Advanced',
      scrollable: true,
      padding: const EdgeInsets.all(20),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const AppIconHeader(
            icon: LucideIcons.terminal,
            title: 'Advanced',
            subtitle: 'Technical details for debugging and development',
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const SectionTitle(text: 'Data'),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.black.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.black.withValues(alpha: 0.04),
                  ),
                ),
                child: SettingsTile(
                  icon: LucideIcons.codeXml,
                  title: 'Show GTFS fields',
                  subtitle: showGtfsFields
                      ? 'Trip and stop IDs are shown on itinerary and departures screens'
                      : 'Show raw trip/stop IDs on itinerary and departures screens',
                  trailingIcon: null,
                  trailing: AppToggleSwitch(
                    value: showGtfsFields,
                    onChanged: (enabled) => context
                        .read<ThemeProvider>()
                        .setShowGtfsFields(enabled),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
