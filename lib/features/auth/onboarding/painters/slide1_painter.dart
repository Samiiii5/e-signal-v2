import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Slide 1 — Image dame africaine bas-gauche + décorations.
/// Remplace l'ancien CustomPainter orbital.
class Slide1Widget extends StatelessWidget {
  const Slide1Widget({super.key});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Image dame — bas-gauche, dépasse légèrement vers le haut
        Positioned(
          bottom: -12,
          left: 0,
          child: Image.asset(
            'design/image_onboarding1.png',
            width: w * 0.60,
            fit: BoxFit.fitWidth,
            alignment: Alignment.bottomLeft,
          ),
        ),
        // Traits décoratifs jaune/vert à droite
        Positioned(
          bottom: 80,
          right: 28,
          child: _AccentStrokes(),
        ),
        // Décorations géométriques bas-droite
        Positioned(
          bottom: 16,
          right: 20,
          child: SizedBox(
            width: 56,
            height: 56,
            child: CustomPaint(painter: _GeoPainter()),
          ),
        ),
      ],
    );
  }
}

class _AccentStrokes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _Bar(width: 34, color: const Color(0xFFFFC107)),
        const SizedBox(height: 7),
        _Bar(width: 22, color: AppColors.green),
        const SizedBox(height: 7),
        _Bar(width: 28, color: const Color(0xFFFFC107).withValues(alpha: 0.55)),
        const SizedBox(height: 7),
        _Bar(width: 16, color: AppColors.green.withValues(alpha: 0.65)),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  final double width;
  final Color color;
  const _Bar({required this.width, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 3.5,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
    );
  }
}

class _GeoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final strokeLight = Paint()
      ..color = AppColors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final strokeGreen = Paint()
      ..color = AppColors.green.withValues(alpha: 0.45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Triangle
    final tri = Path()
      ..moveTo(size.width * 0.1, size.height * 0.95)
      ..lineTo(size.width * 0.5, size.height * 0.05)
      ..lineTo(size.width * 0.9, size.height * 0.95)
      ..close();
    canvas.drawPath(tri, strokeLight);

    // Losange
    final dia = Path()
      ..moveTo(size.width * 0.65, 0)
      ..lineTo(size.width, size.height * 0.28)
      ..lineTo(size.width * 0.65, size.height * 0.56)
      ..lineTo(size.width * 0.30, size.height * 0.28)
      ..close();
    canvas.drawPath(dia, strokeGreen);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
