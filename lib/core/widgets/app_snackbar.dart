import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

abstract class AppSnackbar {
  static SnackBar success(String message) => _build(message, AppColors.green);
  static SnackBar error(String message) => _build(message, const Color(0xFFD32F2F));

  static SnackBar _build(String message, Color bg) {
    return SnackBar(
      content: Text(
        message,
        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
      ),
      backgroundColor: bg,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16),
      duration: const Duration(seconds: 2),
    );
  }
}
