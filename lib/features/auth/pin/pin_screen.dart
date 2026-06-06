import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_colors.dart';

class PinScreen extends StatelessWidget {
  const PinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Entrez votre PIN', style: AppTextStyles.h2),
              const SizedBox(height: 48),
              // Placeholder — sera remplacé par le vrai clavier PIN
              ElevatedButton(
                onPressed: () => context.go('/inbox'),
                child: Text('Accéder (placeholder)', style: AppTextStyles.buttonPrimary),
              ),
              const SizedBox(height: 16),
              Text('Écran PIN — à implémenter', style: AppTextStyles.small.copyWith(color: AppColors.textHint)),
            ],
          ),
        ),
      ),
    );
  }
}
