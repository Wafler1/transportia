import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/app_icon_header.dart';
import '../widgets/app_page_scaffold.dart';
import '../widgets/pressable_highlight.dart';
import '../widgets/section_title.dart';
import '../widgets/icon_badge.dart';
import '../widgets/custom_card.dart';

class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() => _LocationSettingsScreenState();
}

class _LocationSettingsScreenState extends State<LocationSettingsScreen> {
  bool _isLoading = true;
  bool _isLocationServiceEnabled = false;
  PermissionStatus _permissionStatus = PermissionStatus.denied;

  @override
  void initState() {
    super.initState();
    _checkLocationStatus();
  }

  Future<void> _checkLocationStatus() async {
    setState(() => _isLoading = true);

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Permission.location.status;

      if (mounted) {
        setState(() {
          _isLocationServiceEnabled = serviceEnabled;
          _permissionStatus = permission;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _openAppSettings() async {
    await openAppSettings();
    // Refresh status when user returns
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _checkLocationStatus();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    context.watch<ThemeProvider>();
    return AppPageScaffold(
      title: 'Location',
      scrollable: !_isLoading,
      padding: _isLoading ? null : const EdgeInsets.all(20),
      body: _isLoading
          ? Center(
              child: Text(
                'Checking location status...',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.black.withValues(alpha: 0.4),
                ),
              ),
            )
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    final accent = AppColors.accentOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        AppIconHeader(
          icon: LucideIcons.mapPin,
          title: _getStatusTitle(),
          subtitle: _getStatusDescription(),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            const SectionTitle(text: 'Status Details'),
            const SizedBox(height: 16),
            _buildStatusCard(
              'Location Services',
              _isLocationServiceEnabled ? 'Enabled' : 'Disabled',
              _isLocationServiceEnabled ? LucideIcons.check : LucideIcons.x,
              _isLocationServiceEnabled ? accent : const Color(0xFFFF3B30),
            ),
            const SizedBox(height: 12),
            _buildStatusCard(
              'App Permission',
              _getPermissionStatusText(),
              _getPermissionStatusIcon(),
              _getPermissionStatusColor(),
            ),
            const SizedBox(height: 32),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PressableHighlight(
                  onPressed: _openAppSettings,
                  enableHaptics: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Open settings',
                        style: TextStyle(fontSize: 16, color: accent),
                      ),
                      const SizedBox(width: 8),
                      Icon(LucideIcons.settings, size: 20, color: accent),
                    ],
                  ),
                ),
                Container(
                  height: 20,
                  width: 1,
                  color: AppColors.black.withValues(alpha: 0.1),
                ),
                PressableHighlight(
                  onPressed: _isLoading ? () {} : _checkLocationStatus,
                  enableHaptics: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Refresh status',
                        style: TextStyle(fontSize: 16, color: accent),
                      ),
                      const SizedBox(width: 8),
                      Icon(LucideIcons.refreshCw, size: 20, color: accent),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusCard(
    String title,
    String status,
    IconData icon,
    Color color,
  ) {
    return CustomCard.elevated(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(12),
      borderColor: AppColors.black.withValues(alpha: 0.1),
      child: Row(
        children: [
          IconBadge(
            icon: icon,
            size: 48,
            iconSize: 24,
            backgroundColor: color.withValues(alpha: 0.12),
            iconColor: color,
            borderRadius: BorderRadius.circular(12),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.black.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  bool _isLocationEnabled() {
    return _isLocationServiceEnabled &&
        (_permissionStatus == PermissionStatus.granted ||
            _permissionStatus == PermissionStatus.limited);
  }

  String _getStatusTitle() {
    if (_isLocationEnabled()) {
      return 'Location Enabled';
    }
    return 'Location Disabled';
  }

  String _getStatusDescription() {
    if (_isLocationEnabled()) {
      return 'Your location is being used for navigation';
    }
    return 'Enable location to use all features';
  }

  String _getPermissionStatusText() {
    switch (_permissionStatus) {
      case PermissionStatus.granted:
        return 'Allowed';
      case PermissionStatus.denied:
        return 'Denied';
      case PermissionStatus.restricted:
        return 'Restricted';
      case PermissionStatus.limited:
        return 'Limited';
      case PermissionStatus.permanentlyDenied:
        return 'Permanently Denied';
      default:
        return 'Unknown';
    }
  }

  IconData _getPermissionStatusIcon() {
    switch (_permissionStatus) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return LucideIcons.check;
      default:
        return LucideIcons.x;
    }
  }

  Color _getPermissionStatusColor() {
    switch (_permissionStatus) {
      case PermissionStatus.granted:
      case PermissionStatus.limited:
        return AppColors.accentOf(context);
      default:
        return const Color(0xFFFF3B30); // Red
    }
  }
}
