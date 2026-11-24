import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/river_run.dart';
import 'providers/user_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/home_screen.dart';
import 'screens/log_descent_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/run_details_screen.dart';

/// URL paths for the app. Every screen has one, so runs can be shared as
/// links on the web and opened from notifications on mobile.
abstract final class AppRoutes {
  static const signIn = '/sign-in';
  static const home = '/';
  static const logbook = '/logbook';
  static const favourites = '/favourites';
  static const settings = '/settings';
  static const privacy = '/settings/privacy';
  static const logDescent = '/log';

  /// The bottom navigation tabs, in order.
  static const tabs = [home, logbook, favourites, settings];

  static String run(String runId) => '/runs/${Uri.encodeComponent(runId)}';
}

/// Where to send someone, or null to let them through.
///
/// Signed-out visitors go to sign-in, remembering where they were headed.
/// Signed-in users never see the sign-in screen.
String? authRedirect({required bool signedIn, required Uri location}) {
  final atSignIn = location.path == AppRoutes.signIn;
  if (!signedIn) {
    if (atSignIn) return null;
    final from = location.toString();
    return from == AppRoutes.home
        ? AppRoutes.signIn
        : Uri(
            path: AppRoutes.signIn,
            queryParameters: {'from': from},
          ).toString();
  }
  if (atSignIn) {
    final from = location.queryParameters['from'];
    return (from != null && from.startsWith('/')) ? from : AppRoutes.home;
  }
  return null;
}

/// Re-runs the router's redirect when the user signs in or out.
class _AuthRefresh extends ChangeNotifier {
  void notify() => notifyListeners();
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _AuthRefresh();
  ref.listen<bool>(
    userProvider.select((u) => u.isAuthenticated),
    (_, _) => refresh.notify(),
  );
  ref.onDispose(refresh.dispose);

  Page<void> tab(int index) =>
      NoTransitionPage(child: MyHomePage(tabIndex: index));

  final router = GoRouter(
    initialLocation: AppRoutes.home,
    refreshListenable: refresh,
    redirect: (context, state) => authRedirect(
      signedIn: ref.read(userProvider).isAuthenticated,
      location: state.uri,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.signIn,
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(path: AppRoutes.home, pageBuilder: (context, state) => tab(0)),
      GoRoute(path: AppRoutes.logbook, pageBuilder: (context, state) => tab(1)),
      GoRoute(
        path: AppRoutes.favourites,
        pageBuilder: (context, state) => tab(2),
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) => tab(3),
        routes: [
          GoRoute(
            path: 'privacy',
            builder: (context, state) => const PrivacyPolicyScreen(),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.logDescent,
        // A run can be passed as `extra` to pre-select it, e.g. from a run page.
        builder: (context, state) =>
            LogDescentScreen(initialRun: state.extra as RiverRun?),
      ),
      GoRoute(
        path: '/runs/:runId',
        builder: (context, state) =>
            RunDetailsScreen(runId: state.pathParameters['runId']!),
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
