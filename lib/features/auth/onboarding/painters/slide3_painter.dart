import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Slide 3 — Lien de paiement depuis la conversation
/// Téléphone stylisé avec une bulle de message + badge lien de paiement.
class Slide3Painter extends CustomPainter {
  const Slide3Painter();

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
    final purplePaint = Paint()..color = AppColors.purple.withValues(alpha: 0.85);
    final purpleLightPaint = Paint()..color = AppColors.purpleLight.withValues(alpha: 0.9);

    // Téléphone
    const phoneW = 110.0;
    const phoneH = 190.0;
    final phoneRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: phoneW, height: phoneH),
      const Radius.circular(22),
    );
    canvas.drawRRect(phoneRect, fillWhite);
    canvas.drawRRect(phoneRect, strokeWhite);

    // Encoche caméra
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, cy - phoneH / 2 + 14), width: 32, height: 8),
        const Radius.circular(4),
      ),
      Paint()..color = AppColors.white.withValues(alpha: 0.25),
    );

    // Écran (fond légèrement plus clair)
    final screenRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: phoneW - 14, height: phoneH - 38),
      const Radius.circular(14),
    );
    canvas.drawRRect(screenRect, Paint()..color = AppColors.white.withValues(alpha: 0.08));

    // Bulle de message (expéditeur — droite)
    final bubble1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 6, cy - 60, 50, 30),
      const Radius.circular(12),
    );
    canvas.drawRRect(bubble1, Paint()..color = AppColors.green.withValues(alpha: 0.75));
    _drawText(canvas, 'Merci !', Offset(cx - 2, cy - 54), size: 9, color: AppColors.white);

    // Bulle de message (réponse — gauche)
    final bubble2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(cx - 52, cy - 20, 56, 30),
      const Radius.circular(12),
    );
    canvas.drawRRect(bubble2, Paint()..color = AppColors.white.withValues(alpha: 0.2));
    _drawText(canvas, 'Voici\nle lien', Offset(cx - 48, cy - 18), size: 8, color: AppColors.white);

    // Badge lien de paiement (violet)
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy + 30), width: 86, height: 36),
      const Radius.circular(10),
    );
    canvas.drawRRect(badgeRect, Paint()..color = AppColors.purple.withValues(alpha: 0.9));

    // Icône lien (chaîne simplifiée)
    _drawLinkIcon(canvas, Offset(cx - 28, cy + 30));
    _drawText(canvas, 'Payer 15 000 F', Offset(cx - 22, cy + 22), size: 9, weight: FontWeight.w700, color: AppColors.white);

    // Logos Wave + OM en dessous du badge
    _drawBrandPill(canvas, Offset(cx - 20, cy + 60), 'Wave', AppColors.purple);
    _drawBrandPill(canvas, Offset(cx + 18, cy + 60), 'OM', const Color(0xFFFF6B00));

    // Halo rayonnant derrière le téléphone
    for (int r = 1; r <= 3; r++) {
      canvas.drawCircle(
        Offset(cx, cy),
        phoneH / 2 + r * 22,
        Paint()
          ..color = AppColors.white.withValues(alpha: 0.04 * (4 - r))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
  }

  void _drawLinkIcon(Canvas canvas, Offset center) {
    final paint = Paint()
      ..color = AppColors.white.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;
    // Deux demi-cercles liés
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center.dx - 3, center.dy), width: 10, height: 10),
      math.pi / 2, math.pi, false, paint,
    );
    canvas.drawArc(
      Rect.fromCenter(center: Offset(center.dx + 3, center.dy), width: 10, height: 10),
      -math.pi / 2, math.pi, false, paint,
    );
    canvas.drawLine(Offset(center.dx - 3, center.dy - 5), Offset(center.dx + 3, center.dy - 5), paint);
    canvas.drawLine(Offset(center.dx - 3, center.dy + 5), Offset(center.dx + 3, center.dy + 5), paint);
  }

  void _drawBrandPill(Canvas canvas, Offset center, String label, Color color) {
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: 30, height: 16),
      const Radius.circular(8),
    );
    canvas.drawRRect(pill, Paint()..color = color.withValues(alpha: 0.85));
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(color: AppColors.white, fontSize: 7, fontWeight: FontWeight.w700),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
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
          height: 1.3,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
