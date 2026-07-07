import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/services/auth_service.dart';

class SessionService {
  static bool _onboardingSeen = false;
  static bool _loggedIn = false;

  static String? _accessToken;
  static String? _refreshToken;
  static String? _expiresAt;
  static String? _refreshTokenExpiresAt;
  static String? _userId;
  static String? _organizationId;
  static String? _firstName;
  static String? _lastName;
  static String? _displayName;
  static String? _phoneNumber;
  static String? _email;
  static String? _status;
  static String? _kycLevel;

  static bool get onboardingSeen => _onboardingSeen;
  static bool get isLoggedIn => _loggedIn;
  static String? get accessToken => _accessToken;
  static String? get refreshToken => _refreshToken;
  static String? get expiresAt => _expiresAt;
  static String? get refreshTokenExpiresAt => _refreshTokenExpiresAt;
  static String? get userId => _userId;
  static String? get organizationId => _organizationId;
  static String? get firstName => _firstName;
  static String? get lastName => _lastName;
  static String? get displayName => _displayName;
  static String? get phoneNumber => _phoneNumber;
  static String? get email => _email;
  static String? get status => _status;
  static String? get kycLevel => _kycLevel;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
    _loggedIn = prefs.getBool('is_logged_in') ?? false;

    _accessToken = prefs.getString('access_token');
    _refreshToken = prefs.getString('refresh_token');
    _expiresAt = prefs.getString('expires_at');
    _refreshTokenExpiresAt = prefs.getString('refresh_token_expires_at');
    _userId = prefs.getString('user_id');
    _organizationId = prefs.getString('organization_id');
    _firstName = prefs.getString('first_name');
    _lastName = prefs.getString('last_name');
    _displayName = prefs.getString('display_name');
    _phoneNumber = prefs.getString('phone_number');
    _email = prefs.getString('email');
    _status = prefs.getString('status');
    _kycLevel = prefs.getString('kyc_level');
  }

  static void markOnboardingSeen() {
    _onboardingSeen = true;
    SharedPreferences.getInstance().then((p) => p.setBool('onboarding_seen', true));
  }

  /// Appelé après un login ou first-login réussi.
  static Future<void> saveAuthResult(AuthResult result) async {
    _loggedIn = true;
    _accessToken = result.accessToken;
    _refreshToken = result.refreshToken;
    _expiresAt = result.expiresAt;
    _refreshTokenExpiresAt = result.refreshTokenExpiresAt;
    _userId = result.userId;
    _firstName = result.firstName;
    _lastName = result.lastName;
    _displayName = result.displayName;
    _phoneNumber = result.phoneNumber;
    _email = result.email;
    _status = result.status;
    _kycLevel = result.kycLevel;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('access_token', result.accessToken);
    await prefs.setString('refresh_token', result.refreshToken);
    await prefs.setString('expires_at', result.expiresAt);
    await prefs.setString('refresh_token_expires_at', result.refreshTokenExpiresAt);
    await prefs.setString('user_id', result.userId);
    await prefs.setString('first_name', result.firstName);
    await prefs.setString('last_name', result.lastName);
    await prefs.setString('display_name', result.displayName);
    await prefs.setString('phone_number', result.phoneNumber);
    await prefs.setString('email', result.email);
    await prefs.setString('status', result.status);
    await prefs.setString('kyc_level', result.kycLevel);
  }

  /// Persiste l'organisation après l'appel GET /auth/me.
  static Future<void> saveOrganizationId(String orgId) async {
    _organizationId = orgId;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('organization_id', orgId);
  }

  /// Appelé par le refresh intercepteur de ApiClient.
  static Future<void> updateTokens({
    required String accessToken,
    required String refreshToken,
    required String expiresAt,
    required String refreshTokenExpiresAt,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _expiresAt = expiresAt;
    _refreshTokenExpiresAt = refreshTokenExpiresAt;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', accessToken);
    await prefs.setString('refresh_token', refreshToken);
    await prefs.setString('expires_at', expiresAt);
    await prefs.setString('refresh_token_expires_at', refreshTokenExpiresAt);
  }

  static Future<void> logout() async {
    _loggedIn = false;
    _accessToken = null;
    _refreshToken = null;
    _expiresAt = null;
    _refreshTokenExpiresAt = null;
    _userId = null;
    _organizationId = null;
    _firstName = null;
    _lastName = null;
    _displayName = null;
    _phoneNumber = null;
    _email = null;
    _status = null;
    _kycLevel = null;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    for (final key in [
      'access_token', 'refresh_token', 'expires_at', 'refresh_token_expires_at',
      'user_id', 'organization_id', 'first_name', 'last_name', 'display_name',
      'phone_number', 'email', 'status', 'kyc_level',
    ]) {
      await prefs.remove(key);
    }
  }

  static Future<void> setLoggedIn() async {
    _loggedIn = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
  }
}
