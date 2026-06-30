import 'package:flutter/material.dart';

/// Image de la dame — positionnement géré par _Slide1.
class Slide1Widget extends StatelessWidget {
  const Slide1Widget({super.key});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'design/image_onboarding1.png',
      fit: BoxFit.cover,
      alignment: Alignment.topCenter,
    );
  }
}
