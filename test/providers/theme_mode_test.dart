import 'package:brownpaw/providers/theme_mode_provider.dart';
import 'package:brownpaw/screens/settings_screen.dart';
import 'package:brownpaw/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('follows the phone until a choice is made', () async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await Future<void>.delayed(Duration.zero);
    expect(c.read(themeModeProvider), ThemeMode.system);
  });

  test('remembers the choice on this device', () async {
    SharedPreferences.setMockInitialValues({});
    final first = ProviderContainer();
    await first.read(themeModeProvider.notifier).set(ThemeMode.dark);
    first.dispose();

    final next = ProviderContainer();
    addTearDown(next.dispose);
    next.read(themeModeProvider);
    await Future<void>.delayed(Duration.zero);
    expect(next.read(themeModeProvider), ThemeMode.dark);
  });

  testWidgets('the picker switches the mode', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final c = ProviderContainer();
    addTearDown(c.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const Scaffold(body: ThemeModePicker()),
        ),
      ),
    );
    await tester.tap(find.text('Light'));
    await tester.pump();
    expect(c.read(themeModeProvider), ThemeMode.light);
  });
}
