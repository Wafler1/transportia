import 'package:flutter/widgets.dart';
import 'package:geolocator/geolocator.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:permission_handler/permission_handler.dart';
import '../theme/app_colors.dart';
import '../widgets/custom_app_bar.dart';
import '../widgets/pressable_highlight.dart';

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
    return Container(
      color: AppColors.white,
      child: SafeArea(
        child: Column(
          children: [
            CustomAppBar(
              title: 'Location',
              onBackButtonPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: Text(
                        'Checking location status...',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0x66000000),
                        ),
                      ),
                    )
                  : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.accentOf(context).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    LucideIcons.mapPin,
                    size: 36,
                    color: AppColors.accentOf(context),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _getStatusTitle(),
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getStatusDescription(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: Color(0x66000000),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Status Details
          _buildSectionTitle('Status Details'),
          const SizedBox(height: 16),

          _buildStatusCard(
            'Location Services',
            _isLocationServiceEnabled ? 'Enabled' : 'Disabled',
            _isLocationServiceEnabled
                ? LucideIcons.check
                : LucideIcons.x,
            _isLocationServiceEnabled
                ? AppColors.accentOf(context)
                : const Color(0xFFFF3B30),
          ),

          const SizedBox(height: 12),

          _buildStatusCard(
            'App Permission',
            _getPermissionStatusText(),
            _getPermissionStatusIcon(),
            _getPermissionStatusColor(),
          ),

          const SizedBox(height: 32),

          // Actions
          Container(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                PressableHighlight(
                  onPressed: _openAppSettings,
                  enableHaptics: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Text(
                "Open settings",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.accentOf(context),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.settings,
                size: 20,
                color: AppColors.accentOf(context),
              ),
                    ],
                  ),
                ),
                Container(
                  height: 20,
                  width: 1,
                  color: const Color(0x1A000000),
                ),
                PressableHighlight(
                  onPressed: _isLoading ? () {} : _checkLocationStatus,
                  enableHaptics: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                    Text(
                "Refresh Status",
                style: TextStyle(
                  fontSize: 16,
                  color: AppColors.accentOf(context),
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                LucideIcons.refreshCw,
                size: 20,
                color: AppColors.accentOf(context),
              ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.black,
      ),
    );
  }

  Widget _buildStatusCard(
    String title,
    String status,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,
              color: color,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0x66000000),
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
