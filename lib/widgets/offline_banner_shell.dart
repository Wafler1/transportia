import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

class OfflineBannerShell extends StatefulWidget {
  const OfflineBannerShell({super.key, required this.child});

  final Widget child;

  @override
  State<OfflineBannerShell> createState() => _OfflineBannerShellState();
}

class _OfflineBannerShellState extends State<OfflineBannerShell>
    with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isOffline = false;
  bool _dismissed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityUpdate,
    );
  }

  Future<void> _initConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    if (!mounted) return;
    _updateConnectivity(results);
  }

  void _handleConnectivityUpdate(List<ConnectivityResult> results) {
    if (!mounted) return;
    _updateConnectivity(results);
  }

  void _updateConnectivity(List<ConnectivityResult> results) {
    final isOffline = results.contains(ConnectivityResult.none);
    final shouldResetDismissed = !isOffline && _dismissed;
    if (isOffline == _isOffline && !shouldResetDismissed) {
      return;
    }
    setState(() {
      _isOffline = isOffline;
      if (!isOffline) {
        _dismissed = false;
      }
    });
  }

  void _dismissBanner() {
    if (_dismissed) return;
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    final showBanner = _isOffline && !_dismissed;
    return Column(
      children: [
        Expanded(child: widget.child),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            final offsetTween = Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            );
            return SlideTransition(
              position: animation.drive(offsetTween),
              child: child,
            );
          },
          child: showBanner
              ? _OfflineBanner(
                  key: const ValueKey('offline-banner'),
                  onDismiss: _dismissBanner,
                )
              : const SizedBox.shrink(key: ValueKey('offline-empty')),
        ),
      ],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_isOffline && _dismissed && mounted) {
      setState(() => _dismissed = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _subscription?.cancel();
    super.dispose();
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({super.key, required this.onDismiss});

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFD73A3A),
          boxShadow: const [
            BoxShadow(
              color: Color(0x26000000),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'No internet connection. Please reconnect to continue.',
                style: TextStyle(
                  color: AppColors.solidWhite,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onDismiss,
              behavior: HitTestBehavior.opaque,
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(
                  LucideIcons.x,
                  color: AppColors.solidWhite,
                  size: 18,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
