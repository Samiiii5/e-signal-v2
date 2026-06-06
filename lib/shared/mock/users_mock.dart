import '../services/auth_service.dart';

class MockUser {
  final String id;
  final String displayName;
  final String initials;
  final String role;
  final String company;
  final String phone;
  final String password;
  final String pin;

  const MockUser({
    required this.id,
    required this.displayName,
    required this.initials,
    required this.role,
    required this.company,
    required this.phone,
    required this.password,
    required this.pin,
  });
}

const mockUser = MockUser(
  id: 'user_001',
  displayName: 'Kouamé Yao',
  initials: 'KY',
  role: 'Commercial',
  company: 'SCORE360',
  phone: '+2250700000001',
  password: 'esignal2025',
  pin: '1234',
);

class MockAuthService implements AuthService {
  @override
  Future<bool> checkPhone(String phone) async {
    await Future.delayed(const Duration(milliseconds: 600));
    return phone == mockUser.phone;
  }

  @override
  Future<AuthResult> login(String phone, String password) async {
    await Future.delayed(const Duration(milliseconds: 800));
    if (phone == mockUser.phone && password == mockUser.password) {
      return const AuthResult(
        token: 'mock-jwt-token-abc123',
        userId: 'user_001',
        displayName: 'Kouamé Yao',
        avatarUrl: null,
      );
    }
    throw Exception('Identifiants incorrects');
  }

  @override
  Future<void> forgotPassword(String phone) async {
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Future<void> logout() async {
    await Future.delayed(const Duration(milliseconds: 200));
  }
}

final authService = MockAuthService();
