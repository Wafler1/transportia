import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../theme/app_colors.dart';

Future<Uint8List> buildStopMarkerImage(
  Color accentColor, {
  bool isTransfer = false,
}) async {
  final size = isTransfer ? 48.0 : 32.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);

  final outerPaint = Paint()..color = AppColors.black.withValues(alpha: 0.2);
  canvas.drawCircle(center, size / 2, outerPaint);

  final ringPaint = Paint()..color = AppColors.white;
  canvas.drawCircle(center, size / 2 - 2, ringPaint);

  final innerPaint = Paint()..color = accentColor;
  final innerRadius = isTransfer ? size / 2 - 7 : size / 2 - 8;
  canvas.drawCircle(center, innerRadius, innerPaint);

  if (isTransfer) {
    final icon = LucideIcons.arrowLeftRight;
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size * 0.36,
          color: AppColors.solidWhite,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - (textPainter.width / 2),
        center.dy - (textPainter.height / 2),
      ),
    );
  }

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
