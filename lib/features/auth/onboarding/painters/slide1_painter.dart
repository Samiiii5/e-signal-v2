import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Slide 1 — Inbox unifiée
/// 5 bulles de canaux convergeant vers une boîte de réception centrale.
class Slide1Painter extends CustomPainter {
  const Slide1Painter();

  static const _channels = ['WA', 'TT', 'SMS', 'FB', '@'];
  static const _angles = [-100.0, -40.0, 20.0, 80.0, 140.0];

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final orbitR = size.width * 0.37;

    final fillWhite = Paint()..color = AppColors.white.withValues(alpha: 0.15);
    final strokeWhite = Paint()
      ..color = AppColors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final dotPaint = Paint()..color = AppColors.greenLight.withValues(alpha: 0.85);

    // Boîte inbox centrale
    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 96, height: 72),
      const Radius.circular(18),
    );
    canvas.drawRRect(boxRect, fillWhite);
    canvas.drawRRect(boxRect, strokeWhite);
    _drawEnvelope(canvas, Offset(cx, cy));

    for (int i = 0; i < _channels.length; i++) {
      final rad = _angles[i] * math.pi / 180;
      final bx = cx + orbitR * math.cos(rad);
      final by = cy + orbitR * math.sin(rad);

      // Ligne pointillée vers le centre
      _drawDashed(canvas, Offset(bx, by), Offset(cx, cy), strokeWhite);

      // Points de flux
      for (int d = 1; d <= 3; d++) {
        final t = d / 4.5;
        canvas.drawCircle(Offset(bx + (cx - bx) * t, by + (cy - by) * t), 2.5, dotPaint);
      }

      // Bulle du canal
      canvas.drawCircle(Offset(bx, by), 26, fillWhite);
      canvas.drawCircle(Offset(bx, by), 26, strokeWhite);

      // Label
      final tp = TextPainter(
        text: TextSpan(
          text: _channels[i],
          style: const TextStyle(
            color: AppColors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(bx - tp.width / 2, by - tp.height / 2));
    }
  }

  void _drawEnvelope(Canvas canvas, Offset c) {
    const w = 38.0;
    const h = 26.0;
    final rect = Rect.fromCenter(center: c, width: w, height: h);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(5)),
      Paint()..color = AppColors.white,
    );
    final chevron = Path()
      ..moveTo(c.dx - w / 2 + 4, c.dy - h / 2 + 4)
      ..lineTo(c.dx, c.dy + 4)
      ..lineTo(c.dx + w / 2 - 4, c.dy - h / 2 + 4);
    canvas.drawPath(
      chevron,
      Paint()
        ..color = AppColors.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawDashed(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final len = math.sqrt(dx * dx + dy * dy);
    final steps = (len / 10).floor();
    for (int i = 0; i < steps; i++) {
      if (i % 2 == 0) {
        canvas.drawLine(
          Offset(p1.dx + dx * i / steps, p1.dy + dy * i / steps),
          Offset(p1.dx + dx * (i + 0.5) / steps, p1.dy + dy * (i + 0.5) / steps),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
