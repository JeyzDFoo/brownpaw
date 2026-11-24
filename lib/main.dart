import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brownpaw/theme/app_theme.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Enable offline persistence for faster loads and offline
  // support (not supported via Settings on web)
  if (!kIsWeb) {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  }

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
      themeMode: ThemeMode.system,
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
