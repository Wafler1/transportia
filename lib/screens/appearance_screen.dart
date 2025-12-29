import 'package:transportia/widgets/pressable_highlight.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon_header.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/section_title.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  // Predefined accent colors
  final List<Color> _accentColors = [
    const Color.fromARGB(255, 0, 113, 133), // Teal
    const Color(0xFF007AFF), // Blue
    const Color(0xFF34C759), // Green
    const Color(0xFFFF9500), // Orange
    const Color(0xFFFF3B30), // Red
    const Color(0xFFAF52DE), // Purple
    const Color(0xFFFF2D55), // Pink
    const Color(0xFF5856D6), // Indigo
  ];

  Future<void> _saveAccentColor(Color color) async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setAccentColor(color);
  }

  Future<void> _resetToDefault() async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.resetAccentColor();
  }

  Future<void> _saveMapStyle(String style) async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setMapStyle(style);
  }

  Future<void> _saveAppThemeMode(AppThemeMode mode) async {
    final themeProvider = context.read<ThemeProvider>();
    await themeProvider.setAppThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final selectedAccentColor = themeProvider.accentColor;
    final selectedAppThemeMode = themeProvider.appThemeMode;

    return AppPageScaffold(
      title: 'Appearance',
      scrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconHeader(
            icon: LucideIcons.palette,
            title: 'Customize Your Experience',
            subtitle: 'Personalize the look and feel of the app',
            iconColor: selectedAccentColor,
            backgroundColor: selectedAccentColor.withValues(alpha: 0.12),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              const SectionTitle(text: 'Accent Color'),
              const SizedBox(height: 8),
              Text(
                'Choose your preferred accent color',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  const double itemExtent = 56;
                  const double spacing = 12;
                  final availableWidth = constraints.maxWidth;
                  int crossAxisCount =
                      (availableWidth / (itemExtent + spacing)).floor();
                  if (crossAxisCount < 1) {
                    crossAxisCount = 1;
                  } else if (crossAxisCount > _accentColors.length) {
                    crossAxisCount = _accentColors.length;
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _accentColors.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      childAspectRatio: 1,
                    ),
                    itemBuilder: (context, index) {
                      final color = _accentColors[index];
                      final isSelected = selectedAccentColor == color;
                      return GestureDetector(
                        onTap: () => _saveAccentColor(color),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOutCubic,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.solidWhite
                                  : color,
                              width: isSelected ? 3 : 0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(
                                  alpha: isSelected ? 0.4 : 0.25,
                                ),
                                blurRadius: isSelected ? 12 : 6,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: isSelected
                              ? const Icon(
                                  LucideIcons.check,
                                  color: AppColors.solidWhite,
                                  size: 24,
                                )
                              : null,
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Center(
                child: PressableHighlight(
                  onPressed: _resetToDefault,
                  enableHaptics: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Reset to default',
                        style: TextStyle(
                          fontSize: 16,
                          color: selectedAccentColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        LucideIcons.rotateCw,
                        size: 20,
                        color: selectedAccentColor,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const SectionTitle(text: 'App Theme'),
              const SizedBox(height: 8),
              Text(
                'Pick light, dark, or follow your system',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInlineThemeOption(
                      'White',
                      AppThemeMode.light,
                      LucideIcons.sun,
                      const [
                        ThemeProvider.lightBackground,
                        Color(0xFFECECEC),
                      ],
                      selectedAppThemeMode,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInlineThemeOption(
                      'Dark',
                      AppThemeMode.dark,
                      LucideIcons.moon,
                      const [
                        ThemeProvider.darkBackground,
                        Color(0xFF1D1D1D),
                      ],
                      selectedAppThemeMode,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInlineThemeOption(
                      'System',
                      AppThemeMode.system,
                      LucideIcons.settings2,
                      const [
                        ThemeProvider.lightBackground,
                        ThemeProvider.darkBackground,
                      ],
                      selectedAppThemeMode,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              const SectionTitle(text: 'Map Style'),
              const SizedBox(height: 8),
              Text(
                'Select your preferred map appearance',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInlineMapStyleOption(
                      'Default',
                      'default',
                      LucideIcons.map,
                      const [
                        Color(0xFFE8F5E9),
                        Color(0xFF4CAF50),
                        Color(0xFF2196F3),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInlineMapStyleOption(
                      'Light',
                      'light',
                      LucideIcons.sun,
                      const [
                        Color(0xFFFFF9C4),
                        Color(0xFFFFEB3B),
                        Color(0xFF81D4FA),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInlineMapStyleOption(
                      'Dark',
                      'dark',
                      LucideIcons.moon,
                      const [
                        Color(0xFF263238),
                        Color(0xFF37474F),
                        Color(0xFF455A64),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineThemeOption(
    String title,
    AppThemeMode value,
    IconData icon,
    List<Color> previewColors,
    AppThemeMode selectedAppThemeMode,
  ) {
    final themeProvider = context.watch<ThemeProvider>();
    final selectedAccentColor = themeProvider.accentColor;
    final isSelected = selectedAppThemeMode == value;

    return GestureDetector(
      onTap: () => _saveAppThemeMode(value),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius:
              isSelected ? BorderRadius.circular(15) : BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? selectedAccentColor
                : AppColors.black.withValues(alpha: 0.1),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedAccentColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 64,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: previewColors,
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.solidWhite.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isSelected
                        ? selectedAccentColor
                        : AppColors.solidBlack.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color:
                          isSelected ? selectedAccentColor : AppColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInlineMapStyleOption(
    String title,
    String value,
    IconData icon,
    List<Color> previewColors,
  ) {
    final themeProvider = context.watch<ThemeProvider>();
    final selectedAccentColor = themeProvider.accentColor;
    final selectedMapStyle = themeProvider.mapStyle;
    final isSelected = selectedMapStyle == value;

    return GestureDetector(
      onTap: () => _saveMapStyle(value),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: isSelected
              ? BorderRadius.circular(15)
              : BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? selectedAccentColor
                : AppColors.black.withValues(alpha: 0.1),
            width: isSelected ? 2.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: selectedAccentColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : const [
                  BoxShadow(
                    color: Color(0x08000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Preview area
            Container(
              height: 80,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: previewColors,
                ),
              ),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.solidWhite.withValues(alpha: 0.9),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: 24,
                    color: isSelected
                        ? selectedAccentColor
                        : AppColors.solidBlack.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
            // Label area
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? selectedAccentColor : AppColors.black,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
