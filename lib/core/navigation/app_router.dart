import 'package:flutter/material.dart';
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

// ─── Helpers de transition ────────────────────────────────────────────────────

/// Slide depuis la droite — navigation en avant dans la pile.
CustomTransitionPage<void> _slidePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    transitionsBuilder: (_, animation, secondaryAnimation, child) {
      final slide = Tween<Offset>(
        begin: const Offset(1, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic));
      final fade = CurvedAnimation(parent: animation, curve: const Interval(0, 0.5));
      return SlideTransition(
        position: slide,
        child: FadeTransition(opacity: fade, child: child),
      );
    },
  );
}

/// Fade doux — transitions du flux d'auth.
CustomTransitionPage<void> _fadePage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 280),
    transitionsBuilder: (_, animation, __, child) => FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
      child: child,
    ),
  );
}

// ─── Router ───────────────────────────────────────────────────────────────────

GoRouter buildRouter() {
  return GoRouter(
    initialLocation: '/inbox',
    redirect: _rootRedirect,
    routes: [
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _fadePage(state, const OnboardingScreen()),
      ),
      GoRoute(
        path: '/login',
        pageBuilder: (context, state) => _fadePage(state, const LoginPage1Screen()),
        routes: [
          GoRoute(
            path: 'password',
            pageBuilder: (context, state) => _slidePage(
              state,
              LoginPage2Screen(phone: state.extra as String),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/pin',
        pageBuilder: (context, state) => _fadePage(state, const PinScreen()),
        routes: [
          GoRoute(
            path: 'setup',
            pageBuilder: (context, state) => _fadePage(state, const PinSetupScreen()),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        // Pas de transition entre onglets : l'état est préservé (indexedStack)
        pageBuilder: (context, state, shell) => NoTransitionPage(
          child: AppShell(navigationShell: shell),
        ),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/inbox',
              builder: (context, state) => const InboxScreen(),
              routes: [
                GoRoute(
                  path: ':threadId',
                  pageBuilder: (context, state) => _slidePage(
                    state,
                    ChatScreen(threadId: state.pathParameters['threadId']!),
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

// ─── Redirect ─────────────────────────────────────────────────────────────────

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
