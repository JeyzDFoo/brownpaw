import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brownpaw/providers/theme_mode_provider.dart';
import 'package:brownpaw/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Keep Firestore data on the device, on the web app too, so runs, your
  // logbook and gauges you've looked at work with no signal, and entries
  // logged offline sync later.
  // On the web, share the cache between tabs (and the installed app's
  // window): with the default single-tab cache, a second tab can't get the
  // cache and every Firestore read in it fails.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    webPersistentTabManager: WebPersistentMultipleTabManager(),
  );

  // A widget that fails to build shows a quiet note instead of a grey
  // box over the whole tab (the default in release builds).
  ErrorWidget.builder = (details) {
    debugPrint('Widget error: ${details.exception}');
    return const _BuildErrorNote();
  };

  final container = ProviderContainer();
  _openAlertTaps(container);
  runApp(
    UncontrolledProviderScope(container: container, child: const BrownpawApp()),
  );
}

/// Tapping a flow alert opens the gauge it's about. On the web, the
/// service worker opens the link itself (web/firebase-messaging-sw.js).
void _openAlertTaps(ProviderContainer container) {
  if (kIsWeb) return;
  void open(RemoteMessage message) {
    final route = message.data['route'];
    if (route is String && route.startsWith('/')) {
      container.read(routerProvider).push(route);
    }
  }

  FirebaseMessaging.onMessageOpenedApp.listen(open);
  FirebaseMessaging.instance.getInitialMessage().then((m) {
    if (m != null) open(m);
  });
}

class BrownpawApp extends ConsumerWidget {
  const BrownpawApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'brownpaw',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ref.watch(themeModeProvider),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => ColoredBox(
        color: Colors.black,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: child!,
          ),
        ),
      ),
    );
  }
}

class _BuildErrorNote extends StatelessWidget {
  const _BuildErrorNote();

  @override
  Widget build(BuildContext context) {
    return const Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          "Something here couldn't be shown.",
          style: TextStyle(color: Color(0xFF8A8F98), fontSize: 13),
        ),
      ),
    );
  }
}
