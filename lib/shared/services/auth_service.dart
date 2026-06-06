abstract class AuthService {
  /// POST /api/auth/check-phone
  /// Vérifie que le numéro existe et envoie un SMS de confirmation si besoin.
  /// [phone] : numéro complet avec indicatif, ex: "+2250700000000"
  /// Retourne true si le compte existe.
  Future<bool> checkPhone(String phone);

  /// POST /api/auth/login
  /// [phone] : numéro complet avec indicatif
  /// [password] : mot de passe en clair (chiffré côté transport TLS)
  /// Retourne un [AuthResult] avec token et profil utilisateur.
  Future<AuthResult> login(String phone, String password);

  /// POST /api/auth/forgot-password
  /// Envoie un lien de réinitialisation par SMS/email.
  Future<void> forgotPassword(String phone);

  /// DELETE /api/auth/logout
  Future<void> logout();
}

class AuthResult {
  final String token;
  final String userId;
  final String displayName;
  final String? avatarUrl;

  const AuthResult({
    required this.token,
    required this.userId,
    required this.displayName,
    this.avatarUrl,
  });
}
