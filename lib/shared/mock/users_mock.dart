// Données locales de l'utilisateur de test — utilisées pour l'affichage
// et comme fallback en développement hors réseau.
// L'authentification réelle passe par HttpAuthService (auth_service.dart).

class MockUser {
  final String id;
  final String displayName;
  final String initials;
  final String role;
  final String company;
  final String phone;

  const MockUser({
    required this.id,
    required this.displayName,
    required this.initials,
    required this.role,
    required this.company,
    required this.phone,
  });
}

const mockUser = MockUser(
  id: 'user_001',
  displayName: 'Kouamé Yao',
  initials: 'KY',
  role: 'Commercial',
  company: 'SCORE360',
  phone: '+2250700000001',
);
