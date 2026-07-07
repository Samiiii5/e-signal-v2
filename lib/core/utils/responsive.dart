import 'package:flutter/material.dart';

/// Helpers responsivité — valeurs relatives à la taille de l'écran.
///
/// Usage :
///   Responsive.h(context, 0.1)  → 10% de la hauteur écran
///   Responsive.w(context, 0.5)  → 50% de la largeur écran
///   Responsive.sp(context, 14)  → fontSize adapté au textScaleFactor
///   Responsive.vspace(context)  → espacement vertical standard
class Responsive {
  Responsive._();

  /// Fraction de la hauteur écran (ex: 0.08 = 8%).
  static double h(BuildContext context, double fraction) =>
      MediaQuery.of(context).size.height * fraction;

  /// Fraction de la largeur écran (ex: 0.07 = 7%).
  static double w(BuildContext context, double fraction) =>
      MediaQuery.of(context).size.width * fraction;

  /// Font size adapté au textScaleFactor système.
  static double sp(BuildContext context, double size) =>
      size / MediaQuery.of(context).textScaler.scale(1);

  /// Hauteur écran brute.
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  /// Largeur écran brute.
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;

  /// Espacement vertical standard : 3% de la hauteur (≈ 19px sur 640px, 25px sur 844px).
  static double vspace(BuildContext context) => h(context, 0.03);

  /// Petit espacement vertical : 1.5% (≈ 10px sur 640px).
  static double vspaceSmall(BuildContext context) => h(context, 0.015);

  /// Grand espacement vertical : 5% (≈ 32px sur 640px, 42px sur 844px).
  static double vspaceLarge(BuildContext context) => h(context, 0.05);

  /// Padding horizontal standard : 7% de la largeur (≈ 25px sur 360px).
  static double hpad(BuildContext context) => w(context, 0.07);

  /// Hauteur bouton principal : 7% de la hauteur (≈ 45px sur 640px, 59px sur 844px), clamped.
  static double buttonHeight(BuildContext context) =>
      h(context, 0.07).clamp(44.0, 56.0);

  /// Hauteur logo : 11% de la hauteur, clamped entre 80 et 130px.
  static double logoHeight(BuildContext context) =>
      h(context, 0.11).clamp(80.0, 130.0);

  /// Petit logo (écrans secondaires) : 9% de la hauteur, clamped 70–100px.
  static double logoHeightSmall(BuildContext context) =>
      h(context, 0.09).clamp(70.0, 100.0);
}
