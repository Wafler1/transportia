part of '../map_screen.dart';

class _QuickSettingsBottomCard extends StatelessWidget {
  const _QuickSettingsBottomCard({
    required this.onHandleTap,
    required this.onDragStart,
    required this.onDragUpdate,
    required this.onDragEnd,
    required this.onBack,
    required this.bottomSpacer,
    required this.quickButtonAction,
    required this.quickButtonOptions,
    required this.showVehicles,
    required this.hideNonRealtime,
    required this.showStops,
    required this.vehicleModeVisibility,
    required this.onQuickButtonChanged,
    required this.onShowVehiclesChanged,
    required this.onHideNonRealtimeChanged,
    required this.onVehicleModeChanged,
    required this.onShowStopsChanged,
    required this.onOpenAllSettings,
  });

  final VoidCallback onHandleTap;
  final VoidCallback onDragStart;
  final ValueChanged<double> onDragUpdate;
  final ValueChanged<double> onDragEnd;
  final VoidCallback onBack;
  final double bottomSpacer;
  final _QuickButtonAction quickButtonAction;
  final List<_QuickButtonOption> quickButtonOptions;
  final bool showVehicles;
  final bool hideNonRealtime;
  final bool showStops;
  final Map<_VehicleModeGroup, bool> vehicleModeVisibility;
  final ValueChanged<_QuickButtonAction> onQuickButtonChanged;
  final ValueChanged<bool> onShowVehiclesChanged;
  final ValueChanged<bool> onHideNonRealtimeChanged;
  final void Function(_VehicleModeGroup, bool) onVehicleModeChanged;
  final ValueChanged<bool> onShowStopsChanged;
  final VoidCallback onOpenAllSettings;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 14,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _BottomSheetHandle(
              onTap: onHandleTap,
              onDragStart: onDragStart,
              onDragUpdate: onDragUpdate,
              onDragEnd: onDragEnd,
            ),
            _BottomSheetBackButton(onPressed: onBack),
            Expanded(
              child: _QuickSettingsContent(
                quickButtonAction: quickButtonAction,
                quickButtonOptions: quickButtonOptions,
                showVehicles: showVehicles,
                hideNonRealtime: hideNonRealtime,
                showStops: showStops,
                vehicleModeVisibility: vehicleModeVisibility,
                onQuickButtonChanged: onQuickButtonChanged,
                onShowVehiclesChanged: onShowVehiclesChanged,
                onHideNonRealtimeChanged: onHideNonRealtimeChanged,
                onVehicleModeChanged: onVehicleModeChanged,
                onShowStopsChanged: onShowStopsChanged,
                onOpenAllSettings: onOpenAllSettings,
                bottomSpacer: bottomSpacer,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickSettingsContent extends StatelessWidget {
  const _QuickSettingsContent({
    required this.quickButtonAction,
    required this.quickButtonOptions,
    required this.showVehicles,
    required this.hideNonRealtime,
    required this.showStops,
    required this.vehicleModeVisibility,
    required this.onQuickButtonChanged,
    required this.onShowVehiclesChanged,
    required this.onHideNonRealtimeChanged,
    required this.onVehicleModeChanged,
    required this.onShowStopsChanged,
    required this.onOpenAllSettings,
    required this.bottomSpacer,
  });

  final _QuickButtonAction quickButtonAction;
  final List<_QuickButtonOption> quickButtonOptions;
  final bool showVehicles;
  final bool hideNonRealtime;
  final bool showStops;
  final Map<_VehicleModeGroup, bool> vehicleModeVisibility;
  final ValueChanged<_QuickButtonAction> onQuickButtonChanged;
  final ValueChanged<bool> onShowVehiclesChanged;
  final ValueChanged<bool> onHideNonRealtimeChanged;
  final void Function(_VehicleModeGroup, bool) onVehicleModeChanged;
  final ValueChanged<bool> onShowStopsChanged;
  final VoidCallback onOpenAllSettings;
  final double bottomSpacer;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    Text sectionTitle(String title) {
      return Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          letterSpacing: 0.6,
          fontWeight: FontWeight.w700,
          color: AppColors.black.withValues(alpha: 0.5),
        ),
      );
    }

    Widget sectionCard({required String title, required Widget child}) {
      return CustomCard(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [sectionTitle(title), const SizedBox(height: 8), child],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sectionCard(
            title: 'Quick button',
            child: _QuickButtonSelectField(
              value: quickButtonAction,
              options: quickButtonOptions,
              onChanged: onQuickButtonChanged,
            ),
          ),
          sectionCard(
            title: 'Map layers',
            child: LayoutBuilder(
              builder: (context, constraints) {
                const spacing = 12.0;
                final width = (constraints.maxWidth - spacing) / 2;
                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: [
                    SizedBox(
                      width: width,
                      child: _QuickModeCard(
                        label: 'Vehicles',
                        icon: LucideIcons.busFront,
                        selected: showVehicles,
                        onTap: () => onShowVehiclesChanged(!showVehicles),
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: _QuickModeCard(
                        label: 'Stops',
                        icon: LucideIcons.mapPin,
                        selected: showStops,
                        onTap: () => onShowStopsChanged(!showStops),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SizeTransition(
                  sizeFactor: animation,
                  axisAlignment: -1.0,
                  child: child,
                ),
              );
            },
            child: showVehicles
                ? Column(
                    key: const ValueKey('quick-settings-vehicles'),
                    children: [
                      sectionCard(
                        title: 'Live data',
                        child: _QuickToggleRow(
                          label: 'Show only real-time data',
                          value: hideNonRealtime,
                          onChanged: onHideNonRealtimeChanged,
                        ),
                      ),
                      sectionCard(
                        title: 'Vehicle types',
                        child: _VehicleModesGrid(
                          visibility: vehicleModeVisibility,
                          onChanged: onVehicleModeChanged,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(
                    key: ValueKey('quick-settings-vehicles-empty'),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Align(
              alignment: Alignment.center,
              child: PressableHighlight(
                onPressed: onOpenAllSettings,
                highlightColor: accent,
                borderRadius: BorderRadius.circular(14),
                enableHaptics: false,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.settings, size: 18, color: accent),
                    const SizedBox(width: 8),
                    Text(
                      'All settings',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: bottomSpacer),
        ],
      ),
    );
  }
}

class _QuickButtonSelectField extends StatefulWidget {
  const _QuickButtonSelectField({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final _QuickButtonAction value;
  final List<_QuickButtonOption> options;
  final ValueChanged<_QuickButtonAction> onChanged;

  @override
  State<_QuickButtonSelectField> createState() =>
      _QuickButtonSelectFieldState();
}

class _QuickButtonSelectFieldState extends State<_QuickButtonSelectField> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) {
      setState(() => _pressed = value);
    }
  }

  void _openPicker() {
    final pickerOptions = widget.options
        .map(
          (option) => QuickButtonPickerOption<_QuickButtonAction>(
            value: option.action,
            label: option.label,
            icon: option.icon,
            subtitle: option.subtitle,
            enabled: option.enabled,
          ),
        )
        .toList();
    showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Quick button',
      barrierColor: const Color(0x00000000),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, _, __) {
        return QuickButtonPickerSheet<_QuickButtonAction>(
          selected: widget.value,
          options: pickerOptions,
          onSelected: (action) {
            widget.onChanged(action);
          },
        );
      },
      transitionBuilder: (context, animation, _, child) {
        return FadeTransition(opacity: animation, child: child);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final borderColor = AppColors.black.withValues(alpha: 0.12);
    final baseFill = AppColors.black.withValues(alpha: 0.03);
    final pressedFill = AppColors.black.withValues(alpha: 0.06);
    final selected = widget.options.firstWhere(
      (option) => option.action == widget.value,
      orElse: () => widget.options.first,
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _openPicker,
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _pressed ? pressedFill : baseFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Icon(selected.icon, size: 16, color: AppColors.black),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                selected.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.black,
                ),
              ),
            ),
            Icon(
              LucideIcons.chevronDown,
              size: 16,
              color: AppColors.black.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickModeCard extends StatelessWidget {
  const _QuickModeCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : const Color(0x14000000),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? accent : AppColors.black,
                ),
              ),
            ),
            Icon(
              selected ? LucideIcons.check : LucideIcons.plus,
              size: 16,
              color: selected ? accent : const Color(0x33000000),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickToggleRow extends StatelessWidget {
  const _QuickToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final labelColor = value
        ? AppColors.black
        : AppColors.black.withValues(alpha: 0.6);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                ),
              ),
            ),
            _MiniSwitch(value: value),
          ],
        ),
      ),
    );
  }
}

class _MiniSwitch extends StatelessWidget {
  const _MiniSwitch({required this.value});

  final bool value;

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final trackColor = value ? accent : AppColors.black.withValues(alpha: 0.14);
    final borderColor = value
        ? accent.withValues(alpha: 0.7)
        : AppColors.black.withValues(alpha: 0.14);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: 30,
      height: 16,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: trackColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor),
      ),
      child: AnimatedAlign(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: AppColors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.black.withValues(alpha: 0.16),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VehicleModesGrid extends StatelessWidget {
  const _VehicleModesGrid({required this.visibility, required this.onChanged});

  final Map<_VehicleModeGroup, bool> visibility;
  final void Function(_VehicleModeGroup, bool) onChanged;

  @override
  Widget build(BuildContext context) {
    const entries = <_VehicleModeGroup, String>{
      _VehicleModeGroup.train: 'Trains',
      _VehicleModeGroup.metro: 'Metro',
      _VehicleModeGroup.tram: 'Tram',
      _VehicleModeGroup.bus: 'Bus',
      _VehicleModeGroup.ferry: 'Ferries',
      _VehicleModeGroup.lift: 'Lifts',
      _VehicleModeGroup.other: 'Other',
    };

    IconData iconFor(_VehicleModeGroup mode) {
      switch (mode) {
        case _VehicleModeGroup.train:
          return LucideIcons.trainFront;
        case _VehicleModeGroup.metro:
          return LucideIcons.squareArrowDown;
        case _VehicleModeGroup.tram:
          return LucideIcons.tramFront;
        case _VehicleModeGroup.bus:
          return LucideIcons.busFront;
        case _VehicleModeGroup.ferry:
          return LucideIcons.ship;
        case _VehicleModeGroup.lift:
          return LucideIcons.cableCar;
        case _VehicleModeGroup.other:
          return LucideIcons.sparkles;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        final width = (constraints.maxWidth - spacing) / 2;
        final totalWidth = constraints.maxWidth;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final entry in entries.entries)
              SizedBox(
                width: entry.key == _VehicleModeGroup.other
                    ? totalWidth
                    : width,
                child: _QuickModeCard(
                  label: entry.value,
                  icon: iconFor(entry.key),
                  selected: visibility[entry.key] ?? true,
                  onTap: () {
                    final current = visibility[entry.key] ?? true;
                    onChanged(entry.key, !current);
                  },
                ),
              ),
          ],
        );
      },
    );
  }
}
