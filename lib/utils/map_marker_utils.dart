import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../theme/app_colors.dart';

Future<Uint8List> buildStopMarkerImage(Color accentColor) async {
  const double size = 32;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final center = Offset(size / 2, size / 2);

  final outerPaint = Paint()..color = AppColors.black.withValues(alpha: 0.2);
  canvas.drawCircle(center, size / 2, outerPaint);

  final ringPaint = Paint()..color = AppColors.white;
  canvas.drawCircle(center, size / 2 - 2, ringPaint);

  final innerPaint = Paint()..color = accentColor;
  canvas.drawCircle(center, size / 2 - 8, innerPaint);

  final picture = recorder.endRecording();
  final image = await picture.toImage(size.toInt(), size.toInt());
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
