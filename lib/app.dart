import 'package:flutter/widgets.dart';
import 'screens/map_screen.dart';

class EntariaApp extends StatelessWidget {
  const EntariaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return WidgetsApp(
      title: 'Entaria',
      color: const Color(0xFF0b0f14),
      builder: (context, _) => const Directionality(
        textDirection: TextDirection.ltr,
        child: MapScreen(),
      ),
    );
  }
}
