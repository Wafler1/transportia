import 'package:flutter/material.dart';
import 'screens/map_screen.dart';

class EntariaApp extends StatelessWidget {
  const EntariaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Entaria',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorSchemeSeed: const Color(0xFF4F8DF7),
        scaffoldBackgroundColor: const Color(0xFF0b0f14),
      ),
      home: const MapScreen(),
    );
  }
}

