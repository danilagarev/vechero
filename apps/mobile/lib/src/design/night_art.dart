import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'night_theme.dart';

enum NightArtKind { eye, seal, constellation }

/// Original vector artwork. Decorative: all information is also in text.
class NightArt extends StatelessWidget {
  const NightArt({
    super.key,
    this.kind = NightArtKind.eye,
    this.height = 180,
    this.color = NightColors.accent,
    this.onColor = NightColors.ink,
    this.progress = 1,
  });
  final NightArtKind kind;
  final double height;
  final Color color;
  final Color onColor;
  final double progress;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _NightPainter(kind, color, onColor, progress),
      ),
    ),
  );
}

class _NightPainter extends CustomPainter {
  _NightPainter(this.kind, this.color, this.onColor, this.progress);
  final NightArtKind kind;
  final Color color;
  final Color onColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    final scale = math.min(size.width / 280, size.height / 200);
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(scale);
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (kind == NightArtKind.eye) {
      if (progress < 1) {
        canvas.clipRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: 280 * progress,
            height: 200,
          ),
        );
      }
      for (final r in [65.0, 88.0]) {
        canvas.drawCircle(
          Offset.zero,
          r,
          line..color = onColor.withValues(alpha: .3),
        );
      }
      final eye = Path()
        ..moveTo(-110, 0)
        ..quadraticBezierTo(0, -110, 110, 0)
        ..quadraticBezierTo(0, 110, -110, 0)
        ..close();
      canvas.drawPath(eye, Paint()..color = onColor);
      canvas.drawCircle(Offset.zero, 39, Paint()..color = color);
      canvas.drawCircle(Offset.zero, 20, Paint()..color = onColor);
      canvas.drawCircle(
        const Offset(11, -12),
        6,
        Paint()..color = NightColors.text,
      );
      line.color = onColor.withValues(alpha: .6);
      for (var i = 0; i < 4; i++) {
        canvas.save();
        canvas.rotate(i * math.pi / 2);
        canvas.drawLine(const Offset(0, -100), const Offset(0, -80), line);
        canvas.restore();
      }
    } else {
      line.color = color.withValues(alpha: .5);
      if (progress == 1) {
        canvas.drawCircle(Offset.zero, 86, line);
      } else {
        canvas.drawArc(
          Rect.fromCircle(center: Offset.zero, radius: 86),
          -math.pi / 2,
          2 * math.pi * progress,
          false,
          line,
        );
      }
      for (var i = 0; i < 8; i++) {
        canvas.save();
        canvas.rotate(i * math.pi / 4);
        canvas.drawLine(
          Offset(0, kind == NightArtKind.seal ? 0 : 18 * progress),
          Offset(0, (kind == NightArtKind.seal ? 45 : 60) * progress),
          Paint()
            ..color = color
            ..strokeWidth = 4
            ..strokeCap = StrokeCap.round,
        );
        if (kind == NightArtKind.constellation) {
          canvas.drawCircle(
            Offset(0, 66 * progress),
            3 * progress,
            Paint()..color = color,
          );
        }
        canvas.restore();
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NightPainter oldDelegate) =>
      oldDelegate.kind != kind ||
      oldDelegate.color != color ||
      oldDelegate.onColor != onColor ||
      oldDelegate.progress != progress;
}
