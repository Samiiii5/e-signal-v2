import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── Modèle de réponse ────────────────────────────────────────────────────────

class AuthResult {
  final String userId;
  final String email;
  final String phoneNumber;
  final String firstName;
  final String lastName;
  final String status;
  final String kycLevel;
  final String accessToken;
  final String tokenType;
  final String expiresAt;
  final String refreshToken;
  final String refreshTokenExpiresAt;

  const AuthResult({
    required this.userId,
    required this.email,
    required this.phoneNumber,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.kycLevel,
    required this.accessToken,
    required this.tokenType,
    required this.expiresAt,
    required this.refreshToken,
    required this.refreshTokenExpiresAt,
  });

  String get displayName => '$firstName $lastName'.trim().isEmpty
      ? phoneNumber
      : '$firstName $lastName'.trim();

  factory AuthResult.fromJson(Map<String, dynamic> json) => AuthResult(
        userId: json['user_id'] as String? ?? '',
        email: json['email'] as String? ?? '',
        phoneNumber: json['phone_number'] as String? ?? '',
        firstName: json['first_name'] as String? ?? '',
        lastName: json['last_name'] as String? ?? '',
        status: json['status'] as String? ?? '',
        kycLevel: json['kyc_level'] as String? ?? '',
        accessToken: json['access_token'] as String? ?? '',
        tokenType: json['token_type'] as String? ?? 'Bearer',
        expiresAt: json['expires_at'] as String? ?? '',
        refreshToken: json['refresh_token'] as String? ?? '',
        refreshTokenExpiresAt:
            json['refresh_token_expires_at'] as String? ?? '',
      );
}

// ─── Exceptions typées ────────────────────────────────────────────────────────

/// 403 : compte existe mais pas encore activé (mot de passe à définir)
class AccountNotActivatedException implements Exception {
  const AccountNotActivatedException();
}

/// 400 : email déjà utilisé / format invalide / mot de passe trop faible
class BadRequestException implements Exception {
  final String message;
  const BadRequestException(this.message);
}

/// 422 : champ manquant ou type incorrect
class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);
}

/// 502 ou autre erreur serveur
class ServerException implements Exception {
  final int statusCode;
  const ServerException(this.statusCode);
}

// ─── Contrat abstrait ─────────────────────────────────────────────────────────

abstract class AuthService {
  /// Validation locale du numéro — pas d'appel API.
  /// Retourne true si le format est acceptable pour passer à l'étape 2.
  Future<bool> checkPhone(String phone);

  /// POST /auth/login
  /// Lance une [AccountNotActivatedException] si 403,
  /// [BadRequestException] si 400, [ValidationException] si 422,
  /// [ServerException] pour tout autre code ≥ 400.
  Future<AuthResult> login(String phoneOrEmail, String password);

  /// POST /auth/forgot-password  (endpoint à confirmer avec le backend)
  Future<void> forgotPassword(String phone);

  /// Révocation du token (DELETE /auth/logout ou similaire)
  Future<void> logout();
}

// ─── Implémentation HTTP ──────────────────────────────────────────────────────

class HttpAuthService implements AuthService {
  static const _base = 'https://ws.score360.africa';

  @override
  Future<bool> checkPhone(String phone) async {
    // Pas d'endpoint dédié — validation du format seulement
    return phone.replaceAll(RegExp(r'[^\d+]'), '').length >= 8;
  }

  @override
  Future<AuthResult> login(String phoneOrEmail, String password) async {
    final uri = Uri.parse('$_base/auth/login');

    // Détermine si c'est un email ou un numéro
    final bool isEmail = phoneOrEmail.contains('@');
    final body = <String, String>{
      if (isEmail) 'email': phoneOrEmail else 'phone_number': phoneOrEmail,
      'password': password,
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return AuthResult.fromJson(json);
    }

    if (response.statusCode == 403) {
      throw const AccountNotActivatedException();
    }

    String _extractMessage(String body) {
      try {
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['message'] as String? ??
            json['detail'] as String? ??
            'Erreur inconnue';
      } catch (_) {
        return 'Erreur inconnue';
      }
    }

    if (response.statusCode == 400) {
      throw BadRequestException(_extractMessage(response.body));
    }
    if (response.statusCode == 422) {
      throw ValidationException(_extractMessage(response.body));
    }
    throw ServerException(response.statusCode);
  }

  @override
  Future<void> forgotPassword(String phone) async {
    // TODO: confirmer l'endpoint avec le backend
    await http.post(
      Uri.parse('$_base/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phone}),
    );
  }

  @override
  Future<void> logout() async {
    // TODO: ajouter l'access_token dans le header Authorization
    await http.delete(Uri.parse('$_base/auth/logout'));
  }
}

// ─── Instance globale ─────────────────────────────────────────────────────────

final AuthService authService = HttpAuthService();
