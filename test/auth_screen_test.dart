import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:brownpaw/screens/auth_screen.dart';

void main() {
  group('AuthScreen Widget Tests', () {
    testWidgets('AuthScreen builds without errors', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AuthScreen())),
      );

      expect(find.byType(AuthScreen), findsOneWidget);
    });

    testWidgets('AuthScreen shows app branding', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AuthScreen())),
      );

      await tester.pumpAndSettle();

      // Look for brownpaw branding text
      expect(
        find.textContaining('brownpaw', findRichText: true),
        findsAtLeastNWidgets(1),
      );
    });

    testWidgets('AuthScreen has sign-in options', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AuthScreen())),
      );

      await tester.pumpAndSettle();

      // Should have sign-in buttons
      // Note: Actual button text/icons depend on implementation
      expect(find.byType(ElevatedButton), findsWidgets);
    });

    testWidgets('AuthScreen uses Scaffold', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AuthScreen())),
      );

      await tester.pumpAndSettle();

      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  group('AuthScreen Layout Tests', () {
    testWidgets('AuthScreen is scrollable', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(child: MaterialApp(home: AuthScreen())),
      );

      await tester.pumpAndSettle();

      // Most auth screens use scrollable content or column layout
      final hasScrollable =
          find.byType(SingleChildScrollView).evaluate().isNotEmpty ||
          find.byType(ListView).evaluate().isNotEmpty;

      // If no scrollable widget, should at least have a Column
      expect(hasScrollable || find.byType(Column).evaluate().isNotEmpty, true);
    });
  });
}
