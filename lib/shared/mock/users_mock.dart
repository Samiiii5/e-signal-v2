import '../services/auth_service.dart';

// Compte fictif pour les tests
const _mockPhone = '+2250700000001';
const _mockPassword = 'esignal2025';

class MockAuthService implements AuthService {
  @override
  Future<bool> checkPhone(String phone) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return phone == _mockPhone;
  }

  @override
  Future<AuthResult> login(String phone, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (phone == _mockPhone && password == _mockPassword) {
      return const AuthResult(
        token: 'mock-jwt-token-abc123',
        userId: 'user_001',
        displayName: 'Aminata Koné',
        avatarUrl: null,
      );
    }
    throw Exception('Identifiants incorrects');
  }

  @override
  Future<void> forgotPassword(String phone) async {
    await Future.delayed(const Duration(milliseconds: 500));
    // Simule l'envoi d'un SMS
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}

// Singleton utilisable partout tant que le vrai backend n'est pas prêt
final authService = MockAuthService();
