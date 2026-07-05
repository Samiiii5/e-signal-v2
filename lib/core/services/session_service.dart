import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/services/auth_service.dart';

class SessionService {
  static bool _onboardingSeen = false;
  static bool _loggedIn = false;
  static bool _pinValidated = false;

  // Données utilisateur en mémoire après login
  static String? _accessToken;
  static String? _userId;
  static String? _displayName;
  static String? _phoneNumber;
  static String? _email;

  static bool get onboardingSeen => _onboardingSeen;
  static bool get isLoggedIn => _loggedIn;
  static bool get pinValidated => _pinValidated;
  static String? get accessToken => _accessToken;
  static String? get userId => _userId;
  static String? get displayName => _displayName;
  static String? get phoneNumber => _phoneNumber;
  static String? get email => _email;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
    _loggedIn = prefs.getBool('is_logged_in') ?? false;
    _pinValidated = false;

    // Restaure le token si la session était active
    _accessToken = prefs.getString('access_token');
    _userId = prefs.getString('user_id');
    _displayName = prefs.getString('display_name');
    _phoneNumber = prefs.getString('phone_number');
    _email = prefs.getString('email');
  }

  static void markOnboardingSeen() {
    _onboardingSeen = true;
    SharedPreferences.getInstance()
        .then((p) => p.setBool('onboarding_seen', true));
  }

  /// Appelé après un login réussi — persiste le token et le profil.
  static Future<void> saveAuthResult(AuthResult result) async {
    _loggedIn = true;
    _accessToken = result.accessToken;
    _userId = result.userId;
    _displayName = result.displayName;
    _phoneNumber = result.phoneNumber;
    _email = result.email;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('access_token', result.accessToken);
    await prefs.setString('user_id', result.userId);
    await prefs.setString('display_name', result.displayName);
    await prefs.setString('phone_number', result.phoneNumber);
    await prefs.setString('email', result.email);
  }

  static void validatePin() {
    _pinValidated = true;
  }

  static Future<void> logout() async {
    _loggedIn = false;
    _pinValidated = false;
    _accessToken = null;
    _userId = null;
    _displayName = null;
    _phoneNumber = null;
    _email = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    await prefs.remove('access_token');
    await prefs.remove('user_id');
    await prefs.remove('display_name');
    await prefs.remove('phone_number');
    await prefs.remove('email');
  }

  // Conservé pour compatibilité avec l'ancien code
  static Future<void> setLoggedIn() async {
    _loggedIn = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
  }
}
