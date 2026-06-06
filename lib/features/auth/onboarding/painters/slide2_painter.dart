import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Slide 2 — Statistiques en temps réel
/// Représente un mini dashboard : courbe de tendance + 3 barres + 2 métriques.
class Slide2Painter extends CustomPainter {
  const Slide2Painter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    final fillWhite = Paint()..color = AppColors.white.withValues(alpha: 0.15);
    final solidWhite = Paint()..color = AppColors.white;
    final strokeWhite = Paint()
      ..color = AppColors.white.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final greenLight = Paint()..color = AppColors.greenLight.withValues(alpha: 0.9);
    final greenLightFill = Paint()..color = AppColors.greenLight.withValues(alpha: 0.35);

    // Carte principale (dashboard)
    final cardRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy - 10), width: size.width * 0.75, height: size.height * 0.55),
      const Radius.circular(20),
    );
    canvas.drawRRect(cardRect, fillWhite);
    canvas.drawRRect(cardRect, strokeWhite);

    final cardL = cx - size.width * 0.375 + 20;
    final cardT = cy - 10 - size.height * 0.275 + 16;
    final cardR = cx + size.width * 0.375 - 20;
    final cardB = cy - 10 + size.height * 0.275 - 16;
    final innerW = cardR - cardL;
    final innerH = cardB - cardT;

    // Titre de la carte
    _drawText(canvas, 'Activité', Offset(cardL, cardT),
        size: 11, weight: FontWeight.w700, color: AppColors.white);

    // Zone graphique (60% hauteur)
    final chartT = cardT + 22;
    final chartH = innerH * 0.52;
    final chartB = chartT + chartH;

    // Courbe de tendance
    final points = [0.3, 0.5, 0.4, 0.7, 0.6, 0.85, 0.75];
    final pts = List.generate(points.length, (i) {
      final x = cardL + innerW * i / (points.length - 1);
      final y = chartB - chartH * points[i];
      return Offset(x, y);
    });

    // Zone sous la courbe (fill)
    final fillPath = Path()..moveTo(pts.first.dx, chartB);
    for (final p in pts) {
      fillPath.lineTo(p.dx, p.dy);
    }
    fillPath
      ..lineTo(pts.last.dx, chartB)
      ..close();
    canvas.drawPath(fillPath, greenLightFill);

    // Ligne de la courbe
    final curvePath = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (int i = 1; i < pts.length; i++) {
      final cp1 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i - 1].dy);
      final cp2 = Offset((pts[i - 1].dx + pts[i].dx) / 2, pts[i].dy);
      curvePath.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, pts[i].dx, pts[i].dy);
    }
    canvas.drawPath(curvePath, Paint()
      ..color = AppColors.greenLight
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);

    // Point culminant (pic)
    canvas.drawCircle(pts[5], 5, solidWhite);
    canvas.drawCircle(pts[5], 3, greenLight);

    // 3 métriques en bas
    final metricY = chartB + 14;
    final metrics = [
      _Metric('Msgs', '1 240'),
      _Metric('Canal', 'WhatsApp'),
      _Metric('Rép.', '4 min'),
    ];
    final metricW = innerW / 3;
    for (int i = 0; i < metrics.length; i++) {
      final mx = cardL + metricW * i + metricW / 2;
      // Petite carte métrique
      final mRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(mx, metricY + 18), width: metricW - 8, height: 32),
        const Radius.circular(8),
      );
      canvas.drawRRect(mRect, Paint()..color = AppColors.white.withValues(alpha: 0.12));
      _drawText(canvas, metrics[i].label, Offset(mx - metricW / 2 + 6, metricY + 6),
          size: 9, color: AppColors.white.withValues(alpha: 0.65));
      _drawText(canvas, metrics[i].value, Offset(mx - metricW / 2 + 6, metricY + 18),
          size: 10, weight: FontWeight.w700, color: AppColors.white);
    }
  }

  void _drawText(Canvas canvas, String text, Offset offset,
      {double size = 12, FontWeight weight = FontWeight.w400, Color? color}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color ?? AppColors.white,
          fontSize: size,
          fontWeight: weight,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _Metric {
  final String label;
  final String value;
  const _Metric(this.label, this.value);
}
