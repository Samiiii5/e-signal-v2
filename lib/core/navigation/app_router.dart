import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/auth/login/login_page1_screen.dart';
import '../../features/auth/login/login_page2_screen.dart';
import '../../features/auth/onboarding/onboarding_screen.dart';
import '../../features/auth/pin/pin_screen.dart';
import '../../features/auth/pin/pin_setup_screen.dart';
import '../../features/inbox/chat_screen.dart';
import '../../features/inbox/inbox_screen.dart';
import '../../features/payments/payments_screen.dart';
import '../../features/profile/profile_screen.dart';
import 'app_shell.dart';

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/inbox',
    redirect: _rootRedirect,
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage1Screen(),
        routes: [
          GoRoute(
            path: 'password',
            builder: (context, state) => LoginPage2Screen(
              phone: state.extra as String,
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/pin',
        builder: (context, state) => const PinScreen(),
        routes: [
          GoRoute(
            path: 'setup',
            builder: (context, state) => const PinSetupScreen(),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/inbox',
              builder: (context, state) => const InboxScreen(),
              routes: [
                GoRoute(
                  path: ':threadId',
                  builder: (context, state) => ChatScreen(
                    threadId: state.pathParameters['threadId']!,
                  ),
                ),
              ],
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/payments', builder: (context, state) => const PaymentsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
          ]),
        ],
      ),
    ],
  );
}

const _authRoutes = {
  '/onboarding', '/login', '/login/password', '/pin', '/pin/setup',
};

Future<String?> _rootRedirect(context, state) async {
  if (_authRoutes.contains(state.matchedLocation)) return null;

  final prefs = await SharedPreferences.getInstance();
  final onboardingSeen = prefs.getBool('onboarding_seen') ?? false;
  if (!onboardingSeen) return '/onboarding';

  return null;
}
