import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Vert
  static const Color green = Color(0xFF1E9E5E);
  static const Color greenDark = Color(0xFF1A6B3A);
  static const Color greenLight = Color(0xFFE8F8F0);

  // Violet (paiements uniquement)
  static const Color purple = Color(0xFF6C5CE7);
  static const Color purpleDark = Color(0xFF4A3DB5);
  static const Color purpleLight = Color(0xFFF0EEFF);

  // Neutres
  static const Color white = Color(0xFFFFFFFF);
  static const Color backgroundPage = Color(0xFFF7F8FA);
  static const Color borderLight = Color(0xFFE8E9EC);
  static const Color backgroundStatus = Color(0xFFF3F4F6);

  // Textes
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  // Statuts paiement
  static const Color statusPaidBg = Color(0xFFE8F8F0);
  static const Color statusPaidText = Color(0xFF1A6B3A);
  static const Color statusPendingBg = Color(0xFFF0EEFF);
  static const Color statusPendingText = Color(0xFF6C5CE7);
  static const Color statusCreatedBg = Color(0xFFF3F4F6);
  static const Color statusCreatedText = Color(0xFF6B7280);
  static const Color statusExpiredBg = Color(0xFFF3F4F6);
  static const Color statusExpiredText = Color(0xFF9CA3AF);

  // Dégradé onboarding (vert uniquement)
  static const List<Color> onboardingGradient = [greenDark, green];
}
