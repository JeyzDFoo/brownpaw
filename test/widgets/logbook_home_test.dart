import 'package:brownpaw/data/repositories.dart';
import 'package:brownpaw/models/descent.dart';
import 'package:brownpaw/providers/descents_provider.dart';
import 'package:brownpaw/providers/river_runs_provider.dart';
import 'package:brownpaw/screens/home_screen.dart';
import 'package:brownpaw/theme/app_theme.dart';
import 'package:brownpaw/widgets/quick_log_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'quick_log_sheet_test.dart' show cheakamus, tamihi, FakeGauges;

Descent entry(
  String runId,
  String name,
  DateTime date,
  double flow,
  List<String> crew,
) => Descent(
  id: '$runId$date',
  runId: runId,
  runName: name,
  userId: 'u',
  date: date,
  flow: flow,
  flowUnit: 'm³/s',
  crew: crew,
  createdAt: date,
);

Future<void> pumpHome(WidgetTester tester, List<Descent> descents) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allDescentsProvider.overrideWith((ref) => Stream.value(descents)),
        riverRunsStreamProvider.overrideWith(
          (ref) => Stream.value([tamihi, cheakamus]),
        ),
        gaugeRepositoryProvider.overrideWithValue(FakeGauges(24.6)),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: const MyHomePage(tabIndex: 0),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  final year = DateTime.now().year;
  final descents = [
    entry(
      'chilliwack-tamihi',
      'Chilliwack - Tamihi to Vedder',
      DateTime(year, 1, 9),
      22.1,
      ['Alex'],
    ),
    entry('cheakamus-lower', 'Cheakamus - Lower', DateTime(year, 1, 2), 29.8, [
      'Sam',
      'Priya',
    ]),
    entry(
      'chilliwack-tamihi',
      'Chilliwack - Tamihi to Vedder',
      DateTime(year - 1, 6, 1),
      30,
      [],
    ),
  ];

  testWidgets('shows season stats and recent runs with flow status', (
    tester,
  ) async {
    await pumpHome(tester, descents);
    expect(find.text('$year season'), findsOneWidget);
    expect(find.text('days on the water'), findsOneWidget);
    expect(find.text('new this season'), findsOneWidget);
    expect(find.text('1'), findsOneWidget); // one new run this season
    expect(find.text('Chilliwack - Tamihi to Vedder'), findsNWidgets(2));
    expect(find.text('with Sam, Priya'), findsOneWidget);
    expect(find.text('Good'), findsWidgets);
  });

  testWidgets('the bar has five slots with Log in the middle', (tester) async {
    await pumpHome(tester, descents);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations.length, 5);
    expect(bar.selectedIndex, 0);
    expect(find.byType(FloatingActionButton), findsNothing);
  });

  testWidgets('Log opens the quick-log sheet', (tester) async {
    await pumpHome(tester, descents);
    await tester.tap(find.byTooltip('Log a run'));
    await tester.pumpAndSettle();
    expect(find.byType(QuickLogSheet), findsOneWidget);
    expect(find.text('Save to logbook'), findsOneWidget);
  });

  testWidgets('empty logbook invites the first log', (tester) async {
    await pumpHome(tester, const []);
    expect(find.text('Your logbook is empty'), findsOneWidget);
    await tester.tap(find.text('Log your first run'));
    await tester.pumpAndSettle();
    expect(find.byType(QuickLogSheet), findsOneWidget);
  });
}
