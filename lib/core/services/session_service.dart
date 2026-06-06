import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  static bool _onboardingSeen = false;
  static bool _loggedIn = false;
  static bool _pinValidated = false;

  static bool get onboardingSeen => _onboardingSeen;
  static bool get isLoggedIn => _loggedIn;
  static bool get pinValidated => _pinValidated;

  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
    _loggedIn = prefs.getBool('is_logged_in') ?? false;
    _pinValidated = false;
  }

  static void markOnboardingSeen() {
    _onboardingSeen = true;
    SharedPreferences.getInstance().then((p) => p.setBool('onboarding_seen', true));
  }

  static Future<void> setLoggedIn() async {
    _loggedIn = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', true);
  }

  static void validatePin() {
    _pinValidated = true;
  }

  static void logout() {
    _loggedIn = false;
    _pinValidated = false;
    SharedPreferences.getInstance().then((p) => p.setBool('is_logged_in', false));
  }
}
