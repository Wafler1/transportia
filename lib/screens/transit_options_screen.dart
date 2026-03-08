import 'dart:async';
import 'dart:math' as math;

import 'package:transportia/providers/backend_provider.dart';
import 'package:transportia/providers/theme_provider.dart';
import 'package:flutter/cupertino.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/prefs_keys.dart';
import '../environment.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon_header.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/custom_card.dart';
import '../widgets/selectable_icon_card.dart';
import '../widgets/section_title.dart';

const List<String> _transitModeOptions = [
  'WALK',
  'BIKE',
  'RENTAL',
  'CAR',
  'CAR_PARKING',
  'CAR_DROPOFF',
  'ODM',
  'FLEX',
  'TRANSIT',
  'TRAM',
  'SUBWAY',
  'FERRY',
  'AIRPLANE',
  'SUBURBAN',
  'BUS',
  'COACH',
  'RAIL',
  'HIGHSPEED_RAIL',
  'LONG_DISTANCE',
  'NIGHT_RAIL',
  'REGIONAL_FAST_RAIL',
  'REGIONAL_RAIL',
  'CABLE_CAR',
  'FUNICULAR',
  'AERIAL_LIFT',
  'AREAL_LIFT',
  'OTHER',
  'METRO',
];

class TransitOptionsScreen extends StatefulWidget {
  const TransitOptionsScreen({super.key});

  @override
  State<TransitOptionsScreen> createState() => _TransitOptionsScreenState();
}

class _TransitOptionsScreenState extends State<TransitOptionsScreen> {
  final Set<String> _selectedModes = {..._transitModeOptions};
  double _walkingSpeed = 4.8;
  int _transferBuffer = 0;
  bool _advancedExpanded = false;
  bool _endpointVersionsExpanded = false;
  late final TextEditingController _hostController;
  late final FocusNode _hostFocusNode;
  late final TextEditingController _versionController;
  late final FocusNode _versionFocusNode;

  @override
  void initState() {
    super.initState();
    final backend = context.read<BackendProvider>();
    _hostController = TextEditingController(text: backend.host);
    _versionController = TextEditingController(text: backend.apiVersion);
    _hostFocusNode = FocusNode();
    _versionFocusNode = FocusNode();
    _hostFocusNode.addListener(() {
      if (!_hostFocusNode.hasFocus) {
        context.read<BackendProvider>().setHost(_hostController.text);
      }
    });
    _versionFocusNode.addListener(() {
      if (!_versionFocusNode.hasFocus) {
        context.read<BackendProvider>().setApiVersion(_versionController.text);
      }
    });
    backend.addListener(_syncBackendControllers);
    _loadSettings();
  }

  void _syncBackendControllers() {
    final backend = context.read<BackendProvider>();
    if (!_hostFocusNode.hasFocus) _hostController.text = backend.host;
    if (!_versionFocusNode.hasFocus)
      _versionController.text = backend.apiVersion;
  }

  @override
  void dispose() {
    context.read<BackendProvider>().removeListener(_syncBackendControllers);
    _hostController.dispose();
    _hostFocusNode.dispose();
    _versionController.dispose();
    _versionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final prefs = SharedPreferencesAsync();
    final speed = await prefs.getDouble(PrefsKeys.transitWalkingSpeed);
    final buffer = await prefs.getInt(PrefsKeys.transitTransferBuffer);
    final modes = await prefs.getStringList(PrefsKeys.transitSelectedModes);
    if (!mounted) return;
    setState(() {
      if (speed != null) _walkingSpeed = speed;
      if (buffer != null) _transferBuffer = buffer;
      if (modes != null) {
        _selectedModes
          ..clear()
          ..addAll(modes);
      }
    });
  }

  Future<void> _saveWalkingSpeed() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setDouble(PrefsKeys.transitWalkingSpeed, _walkingSpeed);
  }

  Future<void> _saveTransferBuffer() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setInt(PrefsKeys.transitTransferBuffer, _transferBuffer);
  }

  Future<void> _saveSelectedModes() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setStringList(
      PrefsKeys.transitSelectedModes,
      _selectedModes.toList(),
    );
  }

  static const double _walkingMin = 2.0;
  static const double _walkingMax = 7.0;
  static const double _walkingStep = 0.1;
  static const int _transferMin = 0;
  static const int _transferMax = 30;
  static const List<_ModeGroup> _modeGroups = [
    _ModeGroup('Trains', [
      'RAIL',
      'HIGHSPEED_RAIL',
      'LONG_DISTANCE',
      'NIGHT_RAIL',
      'REGIONAL_FAST_RAIL',
      'REGIONAL_RAIL',
    ]),
    _ModeGroup('Metro', ['METRO', 'SUBWAY']),
    _ModeGroup('Tram', ['TRAM', 'SUBURBAN']),
    _ModeGroup('Bus', ['BUS', 'COACH', 'ODM']),
    _ModeGroup('Walking', ['WALK', 'BIKE', 'RENTAL']),
    _ModeGroup('Ferries', ['FERRY']),
    _ModeGroup('Lifts', [
      'CABLE_CAR',
      'FUNICULAR',
      'AERIAL_LIFT',
      'AREAL_LIFT',
    ]),
    _ModeGroup('Flights', ['AIRPLANE']),
    _ModeGroup('Others', ['TRANSIT', 'OTHER']),
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final selectedAccentColor = themeProvider.accentColor;

    return AppPageScaffold(
      title: 'Transit options',
      scrollable: true,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          AppIconHeader(
            icon: LucideIcons.settings2,
            title: 'Tune your defaults',
            subtitle: 'Improve the default routing settings.',
            iconColor: selectedAccentColor,
            backgroundColor: selectedAccentColor.withValues(alpha: 0.12),
          ),
          const SizedBox(height: 28),
          _buildModesCard(context),
          const SizedBox(height: 28),
          _buildWalkingCard(context),
          const SizedBox(height: 28),
          _buildTransferCard(context),
          if (Environment.showBackendSettings) ...[
            const SizedBox(height: 28),
            _buildAdvancedCard(context),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildAdvancedCard(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final backendProvider = context.watch<BackendProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _advancedExpanded = !_advancedExpanded),
          child: Row(
            children: [
              const SectionTitle(text: 'Advanced'),
              const Spacer(),
              AnimatedRotation(
                turns: _advancedExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  LucideIcons.chevronDown,
                  size: 18,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ),
            ],
          ),
        ),
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 200),
          crossFadeState: _advancedExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: const SizedBox.shrink(),
          secondChild: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Backend API host',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              CustomCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                margin: const EdgeInsets.all(0),
                child: Row(
                  children: [
                    Icon(LucideIcons.server, size: 16, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CupertinoTextField.borderless(
                        controller: _hostController,
                        focusNode: _hostFocusNode,
                        placeholder: BackendProvider.defaultHost,
                        style: TextStyle(fontSize: 15, color: AppColors.black),
                        placeholderStyle: TextStyle(
                          fontSize: 15,
                          color: AppColors.black.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        autocorrect: false,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (value) => backendProvider.setHost(value),
                      ),
                    ),
                    if (backendProvider.isCustomHost)
                      GestureDetector(
                        onTap: () => backendProvider.resetHost(),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            LucideIcons.rotateCcw,
                            size: 16,
                            color: AppColors.black.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hostname only, without https:// or trailing slash.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'API version',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black.withValues(alpha: 0.6),
                ),
              ),
              const SizedBox(height: 8),
              CustomCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                margin: const EdgeInsets.all(0),
                child: Row(
                  children: [
                    Icon(LucideIcons.layers, size: 16, color: accent),
                    const SizedBox(width: 10),
                    Expanded(
                      child: CupertinoTextField.borderless(
                        controller: _versionController,
                        focusNode: _versionFocusNode,
                        placeholder: backendProvider.apiVersion,
                        style: TextStyle(fontSize: 15, color: AppColors.black),
                        placeholderStyle: TextStyle(
                          fontSize: 15,
                          color: AppColors.black.withValues(alpha: 0.3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        autocorrect: false,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (value) =>
                            backendProvider.setApiVersion(value),
                      ),
                    ),
                    if (backendProvider.isCustomApiVersion)
                      GestureDetector(
                        onTap: () => backendProvider.resetApiVersion(),
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Icon(
                            LucideIcons.rotateCcw,
                            size: 16,
                            color: AppColors.black.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Affects routing, stop times and map trips. Map stops and geocode stay on v1 unless overridden below. Auto: v5 for transitous hosts, v1 otherwise.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ),
              const SizedBox(height: 16),
              // Nested per-endpoint collapsible
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(
                  () => _endpointVersionsExpanded = !_endpointVersionsExpanded,
                ),
                child: Row(
                  children: [
                    Text(
                      'Per-endpoint versions',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.black.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _endpointVersionsExpanded ? 0.5 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        LucideIcons.chevronDown,
                        size: 16,
                        color: AppColors.black.withValues(alpha: 0.35),
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 200),
                crossFadeState: _endpointVersionsExpanded
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: CustomCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    margin: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _EndpointVersionField(
                          label: 'Plan',
                          endpointKey: 'plan',
                          defaultVersion: backendProvider.apiVersion,
                        ),
                        _EndpointVersionField(
                          label: 'Trip',
                          endpointKey: 'trip',
                          defaultVersion: backendProvider.apiVersion,
                        ),
                        _EndpointVersionField(
                          label: 'Stop times',
                          endpointKey: 'stoptimes',
                          defaultVersion: backendProvider.apiVersion,
                        ),
                        _EndpointVersionField(
                          label: 'Map trips',
                          endpointKey: 'mapTrips',
                          defaultVersion: backendProvider.apiVersion,
                        ),
                        _EndpointVersionField(
                          label: 'Map stops',
                          endpointKey: 'mapStops',
                          defaultVersion: backendProvider.mapStopsVersion,
                        ),
                        _EndpointVersionField(
                          label: 'Geocode',
                          endpointKey: 'geocode',
                          defaultVersion: 'v1',
                          isLast: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModesCard(BuildContext context) {
    final subtitle = 'Select those you wish to use.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Transit modes'),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.black.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            const spacing = 12.0;
            final double width =
                (constraints.maxWidth - spacing) / 2; // two columns
            final totalWidth = constraints.maxWidth;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (final group in _modeGroups)
                  SizedBox(
                    width: group.label == 'Others' ? totalWidth : width,
                    child: SelectableIconCard(
                      label: group.label,
                      icon: _categoryIcon(group.label),
                      selected: _isGroupFullySelected(group),
                      onTap: () {
                        setState(() => _toggleGroupModes(group));
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildWalkingCard(BuildContext context) {
    const presets = [3.6, 4.8, 5.8];
    final accent = AppColors.accentOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Walking pace'),
        const SizedBox(height: 12),

        CustomCard(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.timer, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text(
                    '${_walkingSpeed.toStringAsFixed(1)} km/h',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (int i = 0; i < presets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _QuickValueCard(
                        value: '${presets[i].toStringAsFixed(1)} km/h',
                        selected: (_walkingSpeed - presets[i]).abs() < 0.05,
                        onTap: () {
                          setState(() => _walkingSpeed = presets[i]);
                          _saveWalkingSpeed();
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _StepperSelector(
                value: _walkingSpeed,
                minValue: _walkingMin,
                maxValue: _walkingMax,
                step: _walkingStep,
                label: 'km/h',
                displayBuilder: (val) => val.toStringAsFixed(1),
                onChanged: (val) {
                  setState(() {
                    _walkingSpeed = double.parse(val.toStringAsFixed(1));
                  });
                  _saveWalkingSpeed();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTransferCard(BuildContext context) {
    final presets = [0, 3, 5, 10];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle(text: 'Transfers'),
        const SizedBox(height: 12),

        CustomCard(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.all(0),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    LucideIcons.clock4,
                    size: 18,
                    color: AppColors.accentOf(context),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _transferBuffer == 0
                        ? 'No extra time'
                        : '${_transferBuffer} minute buffer',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColors.black,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  for (int i = 0; i < presets.length; i++) ...[
                    if (i > 0) const SizedBox(width: 12),
                    Expanded(
                      child: _QuickValueCard(
                        value: '${presets[i]} min',
                        selected: _transferBuffer == presets[i],
                        onTap: () {
                          setState(() => _transferBuffer = presets[i]);
                          _saveTransferBuffer();
                        },
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),
              _StepperSelector(
                value: _transferBuffer.toDouble(),
                minValue: _transferMin.toDouble(),
                maxValue: _transferMax.toDouble(),
                step: 1,
                label: 'min',
                displayBuilder: (val) => val.round().toString(),
                onChanged: (val) {
                  setState(() => _transferBuffer = val.round());
                  _saveTransferBuffer();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  bool _isGroupFullySelected(_ModeGroup group) {
    for (final mode in group.modes) {
      if (!_selectedModes.contains(mode)) return false;
    }
    return true;
  }

  void _toggleGroupModes(_ModeGroup group) {
    final fullySelected = _isGroupFullySelected(group);
    if (fullySelected) {
      final removable = _selectedModes.length - group.modes.length;
      if (removable <= 0) return;
      for (final mode in group.modes) {
        if (_selectedModes.length > 1) {
          _selectedModes.remove(mode);
        }
      }
      if (_selectedModes.isEmpty) {
        _selectedModes.add(group.modes.first);
      }
    } else {
      _selectedModes.addAll(group.modes);
    }
    _saveSelectedModes();
  }
}

class _ModeGroup {
  final String label;
  final List<String> modes;

  const _ModeGroup(this.label, this.modes);
}

IconData _categoryIcon(String label) {
  switch (label) {
    case 'Trains':
      return LucideIcons.trainFront;
    case 'Metro':
      return LucideIcons.squareArrowDown;
    case 'Tram':
      return LucideIcons.tramFront;
    case 'Bus':
      return LucideIcons.busFront;
    case 'Walking':
      return LucideIcons.footprints;
    case 'Ferries':
      return LucideIcons.ship;
    case 'Lifts':
      return LucideIcons.cableCar;
    case 'Flights':
      return LucideIcons.planeTakeoff;
    case 'Others':
      return LucideIcons.sparkles;
    default:
      return LucideIcons.layers;
  }
}

class _EndpointVersionField extends StatefulWidget {
  final String label;
  final String endpointKey;
  final String defaultVersion;
  final bool isLast;

  const _EndpointVersionField({
    required this.label,
    required this.endpointKey,
    required this.defaultVersion,
    this.isLast = false,
  });

  @override
  State<_EndpointVersionField> createState() => _EndpointVersionFieldState();
}

class _EndpointVersionFieldState extends State<_EndpointVersionField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    final backend = context.read<BackendProvider>();
    _controller = TextEditingController(
      text: backend.endpointVersionOverride(widget.endpointKey) ?? '',
    );
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) {
        context.read<BackendProvider>().setEndpointVersion(
          widget.endpointKey,
          _controller.text,
        );
      }
    });
    backend.addListener(_sync);
  }

  void _sync() {
    if (!_focusNode.hasFocus) {
      final override = context.read<BackendProvider>().endpointVersionOverride(
        widget.endpointKey,
      );
      final newText = override ?? '';
      if (_controller.text != newText) _controller.text = newText;
    }
  }

  @override
  void dispose() {
    context.read<BackendProvider>().removeListener(_sync);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    final backend = context.watch<BackendProvider>();
    final isOverridden = backend.isEndpointOverridden(widget.endpointKey);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              SizedBox(
                width: 88,
                child: Text(
                  widget.label,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.black.withValues(alpha: 0.65),
                  ),
                ),
              ),
              Expanded(
                child: CupertinoTextField.borderless(
                  controller: _controller,
                  focusNode: _focusNode,
                  placeholder: widget.defaultVersion,
                  style: TextStyle(fontSize: 14, color: AppColors.black),
                  placeholderStyle: TextStyle(
                    fontSize: 14,
                    color: AppColors.black.withValues(alpha: 0.3),
                  ),
                  padding: EdgeInsets.zero,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (v) =>
                      backend.setEndpointVersion(widget.endpointKey, v),
                ),
              ),
              if (isOverridden)
                GestureDetector(
                  onTap: () => backend.resetEndpointVersion(widget.endpointKey),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      LucideIcons.rotateCcw,
                      size: 14,
                      color: accent.withValues(alpha: 0.6),
                    ),
                  ),
                )
              else
                const SizedBox(width: 22),
            ],
          ),
        ),
        if (!widget.isLast)
          Container(
            height: 0.5,
            color: AppColors.black.withValues(alpha: 0.08),
          ),
      ],
    );
  }
}

class _QuickValueCard extends StatelessWidget {
  final String value;
  final bool selected;
  final VoidCallback onTap;

  const _QuickValueCard({
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.12) : AppColors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? accent : const Color(0x14000000),
          ),
        ),
        child: Center(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: selected ? accent : AppColors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _StepperSelector extends StatefulWidget {
  final double value;
  final double minValue;
  final double maxValue;
  final double step;
  final String label;
  final String Function(double) displayBuilder;
  final ValueChanged<double> onChanged;

  const _StepperSelector({
    required this.value,
    required this.minValue,
    required this.maxValue,
    required this.step,
    required this.label,
    required this.displayBuilder,
    required this.onChanged,
  });

  @override
  State<_StepperSelector> createState() => _StepperSelectorState();
}

class _StepperSelectorState extends State<_StepperSelector> {
  double _dragOffset = 0;
  Timer? _repeatTimer;
  int _holdDirection = 0;

  bool get _canIncrement => widget.value < widget.maxValue - widget.step / 2;

  bool get _canDecrement => widget.value > widget.minValue + widget.step / 2;

  int get _stepDecimals {
    final stepString = widget.step.toString();
    if (stepString.contains('.')) {
      return stepString.split('.').last.length;
    }
    return 0;
  }

  double _normalize(double value) {
    final decimals = _stepDecimals;
    if (decimals == 0) return value.roundToDouble();
    final factor = math.pow(10, decimals).toDouble();
    return (value * factor).round() / factor;
  }

  void _change(double delta) {
    double newValue = widget.value + delta;
    newValue = newValue.clamp(widget.minValue, widget.maxValue);
    newValue = _normalize(newValue);
    if ((newValue - widget.value).abs() >= 0.0001) {
      widget.onChanged(newValue);
    }
  }

  void _startHold(int direction) {
    if ((direction > 0 && !_canIncrement) ||
        (direction < 0 && !_canDecrement)) {
      return;
    }
    if (_holdDirection == direction) return;
    _holdDirection = direction;
    _change(direction * widget.step);
    _repeatTimer?.cancel();
    _repeatTimer = Timer(const Duration(milliseconds: 420), () {
      _repeatTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
        if ((_holdDirection > 0 && !_canIncrement) ||
            (_holdDirection < 0 && !_canDecrement)) {
          _stopHold();
        } else {
          _change(_holdDirection * widget.step);
        }
      });
    });
  }

  void _stopHold() {
    _holdDirection = 0;
    _repeatTimer?.cancel();
    _repeatTimer = null;
  }

  void _handleDragStart(DragStartDetails details) {
    _dragOffset = 0;
    _stopHold();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    _dragOffset += details.delta.dx;
    if (_dragOffset >= 14) {
      _startHold(1);
      _dragOffset = 0;
    } else if (_dragOffset <= -14) {
      _startHold(-1);
      _dragOffset = 0;
    }
  }

  void _handleDragEnd(DragEndDetails details) {
    _dragOffset = 0;
    _stopHold();
  }

  @override
  void dispose() {
    _repeatTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = AppColors.accentOf(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: _handleDragStart,
      onHorizontalDragUpdate: _handleDragUpdate,
      onHorizontalDragEnd: _handleDragEnd,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0x0F000000),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0x11000000)),
        ),
        child: Row(
          children: [
            _StepperArrow(
              icon: LucideIcons.chevronLeft,
              enabled: _canDecrement,
              color: accent,
              onTapDown: () => _startHold(-1),
              onTapUp: _stopHold,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.displayBuilder(widget.value),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppColors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.black.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            _StepperArrow(
              icon: LucideIcons.chevronRight,
              enabled: _canIncrement,
              color: accent,
              onTapDown: () => _startHold(1),
              onTapUp: _stopHold,
            ),
          ],
        ),
      ),
    );
  }
}

class _StepperArrow extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final Color color;
  final VoidCallback onTapDown;
  final VoidCallback onTapUp;

  const _StepperArrow({
    required this.icon,
    required this.enabled,
    required this.color,
    required this.onTapDown,
    required this.onTapUp,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => onTapDown() : null,
      onTapUp: (_) => onTapUp(),
      onTapCancel: onTapUp,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Icon(
          icon,
          size: 20,
          color: enabled ? color : color.withValues(alpha: 0.25),
        ),
      ),
    );
  }
}
