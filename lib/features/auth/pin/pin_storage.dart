import 'package:shared_preferences/shared_preferences.dart';

/// Clés SharedPreferences utilisées par le module PIN
const _kPinHash = 'pin_hash';
const _kUserName = 'user_display_name';
const _kUserInitials = 'user_initials';

abstract class PinStorage {
  /// Sauvegarde le nom affiché et les initiales de l'utilisateur connecté.
  static Future<void> saveUser(String displayName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserName, displayName);
    await prefs.setString(_kUserInitials, _initials(displayName));
  }

  /// Retourne le nom affiché, ou null si non connecté.
  static Future<String?> getDisplayName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserName);
  }

  /// Retourne les initiales, ou '?' si non disponibles.
  static Future<String> getInitials() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUserInitials) ?? '?';
  }

  /// Retourne true si un PIN a déjà été défini.
  static Future<bool> hasPinSet() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_kPinHash);
  }

  /// Stocke le hash du PIN.
  static Future<void> savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPinHash, _hash(pin));
  }

  /// Vérifie que le PIN saisi correspond au hash stocké.
  static Future<bool> checkPin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_kPinHash);
    return stored != null && stored == _hash(pin);
  }

  /// Efface le PIN (réinitialisation).
  static Future<void> clearPin() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPinHash);
  }
}

// Hash djb2 salé — suffisant pour un prototype local.
// À remplacer par bcrypt/argon2 en production.
String _hash(String pin) {
  const salt = 'esignal_ci_2025';
  final input = '$salt:$pin';
  var hash = 5381;
  for (final c in input.codeUnits) {
    hash = ((hash << 5) + hash + c) & 0x7FFFFFFF;
  }
  return hash.toRadixString(16).padLeft(8, '0');
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
}
