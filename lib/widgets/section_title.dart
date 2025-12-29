import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';

import '../providers/theme_provider.dart';

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textColor = context.watch<ThemeProvider>().textColor;
    return Text(
      text,
      textAlign: TextAlign.left,
      style: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: textColor,
      ),
    );
  }
}
