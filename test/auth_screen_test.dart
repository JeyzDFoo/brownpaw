import 'package:brownpaw/providers/user_provider.dart';
import 'package:brownpaw/screens/auth_screen.dart';
import 'package:brownpaw/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for the Firebase-backed notifier, recording which sign-in was
/// tapped.
class FakeUserNotifier extends StateNotifier<UserData> implements UserNotifier {
  FakeUserNotifier([UserData? initial]) : super(initial ?? UserData());

  final taps = <String>[];

  @override
  Future<void> signInWithApple() async => taps.add('apple');

  @override
  Future<void> signInWithGoogle() async => taps.add('google');

  @override
  void clearError() => state = UserData();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late FakeUserNotifier notifier;

  Future<void> pump(
    WidgetTester tester, {
    UserData? data,
    ThemeData? theme,
    Size size = const Size(390, 844),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    notifier = FakeUserNotifier(data);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [userProvider.overrideWith((ref) => notifier)],
        child: MaterialApp(
          theme: theme ?? AppTheme.lightTheme,
          home: const AuthScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('shows the brand and both sign-in options', (tester) async {
    await pump(tester);
    expect(find.text('Brownpaw'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  testWidgets('each button starts its own sign-in', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Continue with Apple'));
    await tester.tap(find.text('Continue with Google'));
    expect(notifier.taps, ['apple', 'google']);
  });

  testWidgets('buttons are disabled while signing in', (tester) async {
    await pump(tester, data: UserData(isLoading: true));
    expect(find.text('Continue with Apple'), findsNothing);
    final buttons = tester.widgetList<ElevatedButton>(
      find.byType(ElevatedButton),
    );
    expect(buttons, hasLength(2));
    expect(buttons.every((b) => b.onPressed == null), isTrue);
  });

  testWidgets('an error can be read and dismissed', (tester) async {
    await pump(tester, data: UserData(errorMessage: 'Something went wrong'));
    expect(find.text('Something went wrong'), findsOneWidget);
    await tester.tap(find.byTooltip('Dismiss'));
    await tester.pump();
    expect(find.text('Something went wrong'), findsNothing);
  });

  testWidgets('fits a small phone and dark mode without overflow', (
    tester,
  ) async {
    await pump(tester, theme: AppTheme.darkTheme, size: const Size(320, 480));
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Continue with Google'),
      100,
      scrollable: find.byType(Scrollable),
    );
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
