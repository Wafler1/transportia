import 'package:flutter/widgets.dart';

class GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF000000).withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFFFFFFF).withValues(alpha: 0.08)),
          ),
          padding: const EdgeInsets.all(8),
          child: Icon(icon, color: const Color(0xFFFFFFFF)),
        ),
      ),
    );
  }
}
