import 'package:brownpaw/data/location_service.dart';
import 'package:brownpaw/data/repositories.dart';
import 'package:brownpaw/models/descent.dart';
import 'package:brownpaw/models/river_run.dart';
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

class FakeLocation extends LocationService {
  FakeLocation(this.state, {this.position, this.afterAsk});
  LocationAccess state;
  final LatLng? position;
  final LocationAccess? afterAsk;
  int asks = 0;

  @override
  Future<LocationAccess> access() async => state;

  @override
  Future<LocationAccess> ask() async {
    asks++;
    if (afterAsk != null) state = afterAsk!;
    return state;
  }

  @override
  Future<LatLng?> currentPosition() async =>
      state == LocationAccess.granted ? position : null;
}

Future<void> pumpHome(
  WidgetTester tester,
  List<Descent> descents, {
  LocationService? location,
  List<RiverRun>? runs,
  Map<String, Object> prefs = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allDescentsProvider.overrideWith((ref) => Stream.value(descents)),
        riverRunsStreamProvider.overrideWith(
          (ref) => Stream.value(runs ?? [tamihi, cheakamus]),
        ),
        locationServiceProvider.overrideWithValue(
          location ?? FakeLocation(LocationAccess.unavailable),
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
    // Tab icons are drawn in code, never from the icon font.
    expect(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );
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

  group('put-in check-in', () {
    // Tamihi put-in, near Chilliwack River Rd.
    final atTamihi = tamihi.copyWith(
      putInCoordinates: const {'latitude': 49.0935, 'longitude': -121.8237},
    );
    const nearby = (latitude: 49.0950, longitude: -121.8200); // ~300 m away
    const farAway = (latitude: 49.2827, longitude: -123.1207); // Vancouver

    testWidgets('at a put-in, offers to log that run with today\'s flow', (
      tester,
    ) async {
      await pumpHome(
        tester,
        descents,
        runs: [atTamihi, cheakamus],
        location: FakeLocation(LocationAccess.granted, position: nearby),
      );
      expect(find.text("You're at the put-in"), findsOneWidget);
      expect(find.text('Chilliwack · Tamihi to Vedder'), findsOneWidget);
      expect(
        find.text("Chilliwack is at 24.6 m³/s. Log today's run?"),
        findsOneWidget,
      );

      await tester.tap(find.text('Log it'));
      await tester.pumpAndSettle();
      final sheet = tester.widget<QuickLogSheet>(find.byType(QuickLogSheet));
      expect(sheet.initialRun?.riverId, 'chilliwack-tamihi');
    });

    testWidgets('Not now hides it', (tester) async {
      await pumpHome(
        tester,
        descents,
        runs: [atTamihi, cheakamus],
        location: FakeLocation(LocationAccess.granted, position: nearby),
      );
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(find.text("You're at the put-in"), findsNothing);
    });

    testWidgets('nothing when no put-in is close', (tester) async {
      await pumpHome(
        tester,
        descents,
        runs: [atTamihi, cheakamus],
        location: FakeLocation(LocationAccess.granted, position: farAway),
      );
      expect(find.text("You're at the put-in"), findsNothing);
      expect(find.text('Turn on location'), findsNothing);
    });

    testWidgets('nothing once that run is logged today', (tester) async {
      final today = DateTime.now();
      await pumpHome(
        tester,
        [
          entry(
            'chilliwack-tamihi',
            'Chilliwack - Tamihi to Vedder',
            today,
            24.6,
            [],
          ),
          ...descents,
        ],
        runs: [atTamihi, cheakamus],
        location: FakeLocation(LocationAccess.granted, position: nearby),
      );
      expect(find.text("You're at the put-in"), findsNothing);
    });

    testWidgets('asks for location in context, never on launch', (
      tester,
    ) async {
      final location = FakeLocation(
        LocationAccess.askable,
        position: nearby,
        afterAsk: LocationAccess.granted,
      );
      await pumpHome(
        tester,
        descents,
        runs: [atTamihi, cheakamus],
        location: location,
      );
      expect(location.asks, 0);
      expect(find.text('Know when you’re at a put-in'), findsOneWidget);

      await tester.tap(find.text('Turn on location'));
      await tester.pumpAndSettle();
      expect(location.asks, 1);
      expect(find.text('Know when you’re at a put-in'), findsNothing);
      expect(find.text("You're at the put-in"), findsOneWidget);
    });

    testWidgets('the location card stays away once turned down', (
      tester,
    ) async {
      await pumpHome(
        tester,
        descents,
        location: FakeLocation(LocationAccess.askable),
        prefs: {'location_prompt_dismissed': true},
      );
      expect(find.text('Turn on location'), findsNothing);
    });
  });
}
