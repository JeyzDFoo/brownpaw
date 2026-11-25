import 'package:brownpaw/screens/why_brownpaw_screen.dart';
import 'package:brownpaw/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final dark in [false, true]) {
    testWidgets('Why Brownpaw shows the pitch (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
          home: const WhyBrownpawScreen(),
        ),
      );

      expect(find.text('Why Brownpaw'), findsOneWidget);
      expect(
        find.textContaining('throw caution to the wind and send'),
        findsOneWidget,
      );
      expect(
        find.text("I'm tired of friends dying on the water."),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          'without taking excessive risk',
          findRichText: true,
        ),
        findsOneWidget,
      );
      expect(find.byType(PlayOnceAnimation), findsOneWidget);
    });
  }
}
