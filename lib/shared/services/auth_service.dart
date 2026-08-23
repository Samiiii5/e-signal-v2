import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../core/services/api_client.dart';

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

/// 403 : compte INVITED, pas encore activé → first-login requis.
class AccountNotActivatedException implements Exception {
  final String identifier;
  const AccountNotActivatedException(this.identifier);
}

/// 400 : identifiant ou mot de passe incorrect.
class BadRequestException implements Exception {
  final String message;
  const BadRequestException(this.message);
}

/// 422 : champ manquant ou type incorrect.
class ValidationException implements Exception {
  final String message;
  const ValidationException(this.message);
}

/// 401 : session expirée ou token invalide.
class UnauthorizedException implements Exception {
  const UnauthorizedException();
}

/// 502 ou autre erreur serveur.
class ServerException implements Exception {
  final int statusCode;
  const ServerException(this.statusCode);
}

/// Pas de réseau / timeout.
class NetworkException implements Exception {
  const NetworkException();
}

// ─── Contrat abstrait ─────────────────────────────────────────────────────────

abstract class AuthService {
  /// POST /api/v1.2/auth/login
  Future<AuthResult> login(String identifier, String password);

  /// POST /api/v1.2/auth/first-login  (compte INVITED)
  Future<AuthResult> firstLogin(
    String identifier,
    String tempPassword,
    String newPassword,
  );

  /// GET /api/v1.2/auth/me/capabilities
  /// → retourne le workspace_id du workspace eSignal actif.
  Future<String?> getMe();

  /// POST /api/v1.2/auth/forgot-password
  Future<void> forgotPassword(String identifier);

  /// POST /api/v1.2/auth/forgot-password/request-otp
  Future<void> requestOtp(String identifier);

  /// PATCH /api/v1.2/auth/forgot-password/reset
  Future<void> resetPassword({
    required String identifier,
    required String otpCode,
    required String newPassword,
  });
}

// ─── Implémentation HTTP (Dio) ────────────────────────────────────────────────

class HttpAuthService implements AuthService {
  @override
  Future<AuthResult> login(String identifier, String password) async {
    try {
      final resp = await ApiClient.dio.post(
        '/auth/login',
        data: {'identifier': identifier, 'password': password},
      );
      if (resp.statusCode == 200) {
        return AuthResult.fromJson(resp.data as Map<String, dynamic>);
      }
      return _throwFromResponse(resp.statusCode, resp.data);
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      throw ServerException(e.response?.statusCode ?? 0);
    }
  }

  @override
  Future<AuthResult> firstLogin(
    String identifier,
    String tempPassword,
    String newPassword,
  ) async {
    try {
      final resp = await ApiClient.dio.post(
        '/auth/first-login',
        data: {
          'identifier': identifier,
          'temp_password': tempPassword,
          'new_password': newPassword,
        },
      );
      if (resp.statusCode == 200) {
        return AuthResult.fromJson(resp.data as Map<String, dynamic>);
      }
      return _throwFromResponse(resp.statusCode, resp.data);
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      throw ServerException(e.response?.statusCode ?? 0);
    }
  }

  @override
  Future<String?> getMe() async {
    try {
      final resp = await ApiClient.dio.get('/auth/me/capabilities');
      debugPrint('=== GET /auth/me/capabilities ===');
      debugPrint('=== statusCode: ${resp.statusCode} ===');
      if (resp.statusCode != 200) return null;

      final data = resp.data as Map<String, dynamic>;
      final workspaces = data['workspaces'] as List<dynamic>?;
      if (workspaces == null || workspaces.isEmpty) return null;

      // Cherche le workspace eSignal actif en priorité
      final workspace = workspaces.firstWhere(
        (w) =>
            (w as Map)['slug'] == 'esignal' && (w)['status'] == 'active',
        orElse: () => workspaces.first,
      );

      final workspaceId =
          (workspace as Map<String, dynamic>)['workspace_id'] as String?;
      debugPrint('=== workspace_id sélectionné: $workspaceId ===');
      return workspaceId;
    } on DioException {
      return null;
    }
  }

  @override
  Future<void> forgotPassword(String identifier) async {
    try {
      final resp = await ApiClient.dio.post(
        '/auth/forgot-password',
        data: {'identifier': identifier},
      );
      if (resp.statusCode != 200 && resp.statusCode != 204) {
        _throwFromResponse(resp.statusCode, resp.data);
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      throw ServerException(e.response?.statusCode ?? 0);
    }
  }

  @override
  Future<void> requestOtp(String identifier) async {
    try {
      final resp = await ApiClient.dio.post(
        '/auth/forgot-password/request-otp',
        data: {'identifier': identifier},
      );
      if (resp.statusCode != 200 &&
          resp.statusCode != 202 &&
          resp.statusCode != 204) {
        _throwFromResponse(resp.statusCode, resp.data);
      }
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      throw ServerException(e.response?.statusCode ?? 0);
    }
  }

  @override
  Future<void> resetPassword({
    required String identifier,
    required String otpCode,
    required String newPassword,
  }) async {
    try {
      final resp = await ApiClient.dio.patch(
        '/auth/forgot-password/reset',
        data: {
          'identifier': identifier,
          'otp_code': otpCode,
          'new_password': newPassword,
        },
      );
      if (resp.statusCode == 200) return;
      _throwFromResponse(resp.statusCode, resp.data);
    } on DioException catch (e) {
      if (_isNetworkError(e)) throw const NetworkException();
      throw ServerException(e.response?.statusCode ?? 0);
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

Never _throwFromResponse(int? status, dynamic data) {
  if (status == 401) throw const UnauthorizedException();
  if (status == 403) {
    final id = data is Map<String, dynamic>
        ? (data['identifier'] as String? ?? '')
        : '';
    throw AccountNotActivatedException(id);
  }
  if (status == 400) throw BadRequestException(_extractMsg(data));
  if (status == 422) throw ValidationException(_extractMsg(data));
  throw ServerException(status ?? 0);
}

bool _isNetworkError(DioException e) =>
    e.type == DioExceptionType.connectionError ||
    e.type == DioExceptionType.sendTimeout ||
    e.type == DioExceptionType.receiveTimeout ||
    e.type == DioExceptionType.connectionTimeout;

String _extractMsg(dynamic data) {
  final raw = data is Map<String, dynamic>
      ? (data['message'] as String? ?? data['detail'] as String? ?? '')
      : '';
  return _translateApiMessage(raw.isNotEmpty ? raw : 'Erreur inconnue');
}

String _translateApiMessage(String msg) {
  const translations = <String, String>{
    'Invalid credentials': 'Identifiant ou mot de passe incorrect.',
    'invalid credentials': 'Identifiant ou mot de passe incorrect.',
    'Password must contain at least one uppercase letter':
        'Le mot de passe doit contenir au moins une lettre majuscule.',
    'Password must contain at least one special character':
        'Le mot de passe doit contenir au moins un caractère spécial.',
    'Password must contain at least one digit':
        'Le mot de passe doit contenir au moins un chiffre.',
    'Password must be at least 8 characters':
        'Le mot de passe doit contenir au moins 8 caractères.',
    'Password must be at least 8 characters long':
        'Le mot de passe doit contenir au moins 8 caractères.',
    'User not found': 'Aucun compte associé à cet identifiant.',
    'Account not found': 'Aucun compte associé à cet identifiant.',
    'Account already activated': 'Ce compte est déjà activé.',
    'Invalid OTP': 'Code OTP invalide ou expiré.',
    'OTP expired': 'Code OTP expiré. Demandez un nouveau code.',
    'OTP not found': 'Code OTP invalide ou expiré.',
    'Token expired': 'Session expirée. Reconnectez-vous.',
    'Temporary password is incorrect': 'Mot de passe temporaire incorrect.',
    'Erreur inconnue': 'Une erreur est survenue. Réessayez.',
  };

  if (translations.containsKey(msg)) return translations[msg]!;

  final lower = msg.toLowerCase();
  for (final entry in translations.entries) {
    if (lower.contains(entry.key.toLowerCase())) return entry.value;
  }

  if (msg.contains('é') ||
      msg.contains('è') ||
      msg.contains('à') ||
      msg.contains('ê') ||
      msg.contains('î') ||
      msg.contains('ô')) {
    return msg;
  }

  return 'Une erreur est survenue. Réessayez.';
}

// ─── Instance globale ─────────────────────────────────────────────────────────

final AuthService authService = HttpAuthService();