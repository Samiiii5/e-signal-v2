import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/login/login_page1_screen.dart';
import '../../features/auth/login/login_page2_screen.dart';
import '../../features/auth/login/set_password_screen.dart';
import '../../features/auth/onboarding/onboarding_screen.dart';
import '../../features/auth/pin/pin_screen.dart';
import '../../features/auth/pin/pin_setup_screen.dart';
import '../../features/inbox/chat_screen.dart';
import '../../features/inbox/inbox_screen.dart';
import '../../features/payments/create_link_screen.dart';
import '../../features/payments/payments_screen.dart';
import '../../features/payments/transaction_detail_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../shared/mock/payments_mock.dart';
import '../../features/stats/stats_screen.dart';
import '../../core/services/navigation_service.dart';
import '../../core/services/session_service.dart';
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
  final router = GoRouter(
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
              LoginPage2Screen(identifier: state.extra as String),
            ),
          ),
          GoRoute(
            path: 'set-password',
            pageBuilder: (context, state) => _slidePage(
              state,
              SetPasswordScreen(identifier: state.extra as String),
            ),
          ),
        ],
      ),
      // Route top-level pour l'activation de compte (403 first-login).
      GoRoute(
        path: '/set-password',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, String>? ?? {};
          return _slidePage(
            state,
            SetPasswordScreen(identifier: extra['identifier'] ?? ''),
          );
        },
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
      // Route hors shell — s'affiche plein écran sans bottom nav bar
      GoRoute(
        path: '/payment-detail',
        pageBuilder: (context, state) => _slidePage(
          state,
          TransactionDetailScreen(link: state.extra as PaymentLink),
        ),
      ),
      // Route hors shell — création de lien de paiement (sans bottom nav bar)
      GoRoute(
        path: '/create-link',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, String?>? ?? {};
          return _slidePage(
            state,
            CreateLinkScreen(
              contactName: extra['contactName'],
              threadId: extra['threadId'],
            ),
          );
        },
      ),
      // Route hors shell — conversation (sans bottom nav bar)
      GoRoute(
        path: '/inbox/:threadId',
        pageBuilder: (context, state) => _slidePage(
          state,
          ChatScreen(threadId: state.pathParameters['threadId']!),
        ),
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
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/stats', builder: (context, state) => const StatsScreen()),
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
  // Câble le callback de session expirée pour l'intercepteur Dio.
  NavigationService.onSessionExpired = () => router.go('/login');
  return router;
}

// ─── Redirect ─────────────────────────────────────────────────────────────────

const _authRoutes = {
  '/onboarding', '/login', '/login/password', '/login/set-password',
  '/set-password', '/pin', '/pin/setup',
};

String? _rootRedirect(BuildContext context, GoRouterState state) {
  if (_authRoutes.contains(state.matchedLocation)) return null;
  if (!SessionService.onboardingSeen) return '/onboarding';
  if (!SessionService.isLoggedIn) return '/login';
  if (!SessionService.pinValidated) return '/pin';
  return null;
}
