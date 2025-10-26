import 'package:flutter/widgets.dart';
import 'package:oktoast/oktoast.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

bool _globalToastOpen = false;

void showValidationToast(
  BuildContext context,
  String message, {
  Color accentColor = const Color.fromARGB(255, 228, 164, 0),
}) {
  if (_globalToastOpen) return;
  _globalToastOpen = true;

  final toastKey = GlobalKey<_DismissableToastState>();
  showToastWidget(
    _DismissableToast(
      key: toastKey,
      accentColor: accentColor,
      message: message,
      onRequestClose: () {
        dismissAllToast();
        _globalToastOpen = false;
      },
    ),
    position: ToastPosition.bottom,
    handleTouch: true,
    duration: const Duration(days: 1),
  );

  Future.delayed(const Duration(milliseconds: 2400), () {
    toastKey.currentState?.close();
  });
}

class _DismissableToast extends StatefulWidget {
  const _DismissableToast({
    super.key,
    required this.accentColor,
    required this.message,
    required this.onRequestClose,
  });

  final Color accentColor;
  final String message;
  final VoidCallback onRequestClose;

  @override
  State<_DismissableToast> createState() => _DismissableToastState();
}

class _DismissableToastState extends State<_DismissableToast> {
  bool _closing = false;

  void close() {
    if (_closing) return;
    setState(() => _closing = true);
    Future.delayed(const Duration(milliseconds: 220), widget.onRequestClose);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: close,
      behavior: HitTestBehavior.opaque,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        offset: _closing ? const Offset(0, 0.2) : Offset.zero,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          opacity: _closing ? 0.0 : 1.0,
          child: _ToastCard(
            accentColor: widget.accentColor,
            message: widget.message,
          ),
        ),
      ),
    );
  }
}

class _ToastCard extends StatelessWidget {
  const _ToastCard({required this.accentColor, required this.message});

  final Color accentColor;
  final String message;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(14);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xEEFFFFFF),
        borderRadius: borderRadius,
        border: Border.all(color: const Color(0x1A000000)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0x26FF8A00), Color(0x00FF8A00)],
                    stops: [0.0, 0.28],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.triangleAlert, color: accentColor, size: 18),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    message,
                    style: const TextStyle(
                      color: Color(0xFF000000),
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
