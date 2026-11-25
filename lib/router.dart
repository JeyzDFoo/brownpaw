import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'models/river_run.dart';
import 'providers/user_provider.dart';
import 'screens/auth_screen.dart';
import 'screens/descent_screen.dart';
import 'screens/gauge_screen.dart';
import 'screens/home_screen.dart';
import 'screens/log_descent_screen.dart';
import 'screens/privacy_policy_screen.dart';
import 'screens/why_brownpaw_screen.dart';
import 'screens/run_details_screen.dart';

/// URL paths for the app. Every screen has one, so runs can be shared as
/// links on the web and opened from notifications on mobile.
abstract final class AppRoutes {
  static const signIn = '/sign-in';
  static const home = '/';
  static const gauges = '/gauges';
  static const guide = '/guide';
  static const me = '/me';
  static const privacy = '/me/privacy';
  static const why = '/me/why';
  static const logDescent = '/log';

  /// Where the app opens: the Gauges tab.
  static const start = gauges;

  /// The bottom navigation tabs, in order. The centre Log button is not a
  /// tab: it opens the quick-log sheet over whichever tab is showing.
  static const tabs = [home, gauges, guide, me];

  static String run(String runId) => '/runs/${Uri.encodeComponent(runId)}';

  /// A run in your logbook. A sub-page of the Logbook tab, so back
  /// returns there.
  static String descent(String descentId) =>
      '/logbook/${Uri.encodeComponent(descentId)}';

  static String gauge(String gaugeId) =>
      '/gauges/${Uri.encodeComponent(gaugeId)}';
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
    return (from == AppRoutes.home || from == AppRoutes.start)
        ? AppRoutes.signIn
        : Uri(
            path: AppRoutes.signIn,
            queryParameters: {'from': from},
          ).toString();
  }
  if (atSignIn) {
    final from = location.queryParameters['from'];
    return (from != null && from.startsWith('/')) ? from : AppRoutes.start;
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
    initialLocation: AppRoutes.start,
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
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => tab(0),
        routes: [
          GoRoute(
            path: 'logbook/:descentId',
            builder: (context, state) =>
                DescentScreen(descentId: state.pathParameters['descentId']!),
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.gauges,
        pageBuilder: (context, state) => tab(1),
        routes: [
          GoRoute(
            path: ':gaugeId',
            builder: (context, state) =>
                GaugeScreen(gaugeId: state.pathParameters['gaugeId']!),
          ),
        ],
      ),
      GoRoute(path: AppRoutes.guide, pageBuilder: (context, state) => tab(2)),
      GoRoute(
        path: AppRoutes.me,
        pageBuilder: (context, state) => tab(3),
        routes: [
          GoRoute(
            path: 'privacy',
            builder: (context, state) => const PrivacyPolicyScreen(),
          ),
          GoRoute(
            path: 'why',
            builder: (context, state) => const WhyBrownpawScreen(),
          ),
        ],
      ),
      // Old tab paths, kept so earlier links still work.
      GoRoute(path: '/logbook', redirect: (_, _) => AppRoutes.home),
      GoRoute(path: '/favourites', redirect: (_, _) => AppRoutes.gauges),
      GoRoute(path: '/settings', redirect: (_, _) => AppRoutes.me),
      GoRoute(path: '/community', redirect: (_, _) => AppRoutes.home),
      GoRoute(path: '/map', redirect: (_, _) => AppRoutes.guide),
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
