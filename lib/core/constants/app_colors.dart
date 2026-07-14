import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2D1B69);
  static const Color primaryLight = Color(0xFFF0EEFF);
  static const Color primaryMid = Color(0xFF4C3494);

  static const Color green = Color(0xFF22C55E);
  static const Color greenDark = Color(0xFF15803D);
  static const Color greenLight = Color(0xFFDCFCE7);

  // Keep purple aliases pointing to primary for payment compat
  static const Color purple = Color(0xFF2D1B69);
  static const Color purpleDark = Color(0xFF1A0F40);
  static const Color purpleLight = Color(0xFFF0EEFF);

  static const Color error = Color(0xFFEF4444);

  static const Color white = Color(0xFFFFFFFF);
  static const Color backgroundPage = Color(0xFFF5F5F5);
  static const Color backgroundStatus = Color(0xFFF3F4F6);
  static const Color borderLight = Color(0xFFE5E7EB);

  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);

  static const Color statusPaidBg = Color(0xFFDCFCE7);
  static const Color statusPaidText = Color(0xFF15803D);
  static const Color statusPendingBg = Color(0xFFF0EEFF);
  static const Color statusPendingText = Color(0xFF2D1B69);
  static const Color statusCreatedBg = Color(0xFFF3F4F6);
  static const Color statusCreatedText = Color(0xFF6B7280);
  static const Color statusExpiredBg = Color(0xFFF3F4F6);
  static const Color statusExpiredText = Color(0xFF9CA3AF);

  static const List<Color> onboardingGradient = [Color(0xFF2D1B69), Color(0xFF4C3494)];
}
