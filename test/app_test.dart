import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brownpaw/main.dart';

void main() {
  group('App Initialization Tests', () {
    testWidgets('App builds without errors', (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(const ProviderScope(child: BrownpawApp()));

      // Verify that the app builds
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('App has correct theme modes', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: BrownpawApp()));

      final MaterialApp app = tester.widget(find.byType(MaterialApp));

      // Verify theme configuration
      expect(app.theme, isNotNull);
      expect(app.darkTheme, isNotNull);
      expect(app.themeMode, ThemeMode.system);
    });

    testWidgets('App title is correct', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: BrownpawApp()));

      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.title, 'brownpaw');
    });

    testWidgets('Debug banner is disabled', (WidgetTester tester) async {
      await tester.pumpWidget(const ProviderScope(child: BrownpawApp()));

      final MaterialApp app = tester.widget(find.byType(MaterialApp));
      expect(app.debugShowCheckedModeBanner, false);
    });
  });
}
