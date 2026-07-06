import 'package:dio/dio.dart';
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
/// Transporte l'identifier normalisé renvoyé par le backend dans le body 403.
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

/// 502 ou autre erreur serveur / réseau.
class ServerException implements Exception {
  final int statusCode;
  const ServerException(this.statusCode);
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

  /// GET /api/v1.2/auth/me  → retourne l'organization_id du premier élément.
  Future<String?> getMe();

  /// POST /api/v1.2/auth/set-pin
  Future<void> setPin(String pin);

  /// POST /api/v1.2/auth/forgot-password
  Future<void> forgotPassword(String identifier);
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
      // validateStatus = accepte tout → on vérifie le code ici, sans ambiguïté.
      if (resp.statusCode == 200) {
        return AuthResult.fromJson(resp.data as Map<String, dynamic>);
      }
      // ignore: avoid_print
      print('STATUS CODE REÇU : ${resp.statusCode}');
      // ignore: avoid_print
      print('BODY REÇU : ${resp.data}');
      return _throwFromResponse(resp.statusCode, resp.data);
    } on DioException catch (e) {
      // Seules les erreurs réseau (timeout, pas de connexion) arrivent ici.
      // ignore: avoid_print
      print('DioException réseau : ${e.type} / ${e.message}');
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
      throw ServerException(e.response?.statusCode ?? 0);
    }
  }

  @override
  Future<String?> getMe() async {
    try {
      final resp = await ApiClient.dio.get('/auth/me');
      if (resp.statusCode != 200) return null;
      final data = resp.data as Map<String, dynamic>;
      final orgs = data['organizations'] as List<dynamic>?;
      if (orgs != null && orgs.isNotEmpty) {
        final first = orgs.first as Map<String, dynamic>;
        return first['organization_id'] as String?;
      }
      return null;
    } on DioException {
      return null;
    }
  }

  @override
  Future<void> setPin(String pin) async {
    try {
      final resp = await ApiClient.dio.post('/auth/set-pin', data: {'pin': pin});
      if (resp.statusCode != 200) _throwFromResponse(resp.statusCode, resp.data);
    } on DioException catch (e) {
      throw ServerException(e.response?.statusCode ?? 0);
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
      throw ServerException(e.response?.statusCode ?? 0);
    }
  }
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

/// Inspecte directement le statusCode HTTP → lance l'exception métier appropriée.
/// Jamais de DioException ici — on travaille sur la réponse décodée.
Never _throwFromResponse(int? status, dynamic data) {
  if (status == 403) {
    // Body exact : {"code": "account_not_activated", "identifier": "..."}
    final id = data is Map<String, dynamic>
        ? (data['identifier'] as String? ?? '')
        : '';
    throw AccountNotActivatedException(id);
  }
  if (status == 400) throw BadRequestException(_extractMsg(data));
  if (status == 422) throw ValidationException(_extractMsg(data));
  throw ServerException(status ?? 0);
}

String _extractMsg(dynamic data) {
  if (data is Map<String, dynamic>) {
    return data['message'] as String? ??
        data['detail'] as String? ??
        'Erreur inconnue';
  }
  return 'Erreur inconnue';
}

// ─── Instance globale ─────────────────────────────────────────────────────────

final AuthService authService = HttpAuthService();
