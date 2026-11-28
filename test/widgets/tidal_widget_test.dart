import 'dart:io';
import 'dart:math' as math;

import 'package:brownpaw/data/gauge_repository.dart';
import 'package:brownpaw/data/repositories.dart';
import 'package:brownpaw/domain/flow_ranges.dart';
import 'package:brownpaw/domain/gauges.dart';
import 'package:brownpaw/domain/tidal.dart';
import 'package:brownpaw/models/river_run.dart';
import 'package:brownpaw/providers/descents_provider.dart';
import 'package:brownpaw/providers/flow_alerts_provider.dart';
import 'package:brownpaw/providers/gauges_provider.dart';
import 'package:brownpaw/providers/release_schedule_provider.dart';
import 'package:brownpaw/providers/river_runs_provider.dart';
import 'package:brownpaw/screens/gauge_screen.dart';
import 'package:brownpaw/screens/gauges_screen.dart';
import 'package:brownpaw/theme/app_theme.dart';
import 'package:brownpaw/widgets/favourite_star.dart';
import 'package:brownpaw/widgets/tidal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dam_release_widget_test.dart' show loadFonts;
import 'gauges_test.dart' show FakeAlerts;
import 'quick_log_sheet_test.dart' show FakeGauges;

/// BC wall time (UTC-7) in Nov 2026.
DateTime bc(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour + 7, minute);

/// Six weeks of Sechelt Rapids-like currents: semidiurnal, springs and
/// neaps over two weeks, one big and one small flood a day. Starts with
/// Dairiki's Nov 27 morning: slack 4:43 AM, 17 kt near 8 AM.
TidalPredictions skook() {
  const half = Duration(hours: 6, minutes: 12, seconds: 30);
  final quarter = Duration(seconds: half.inSeconds ~/ 2);
  final currents = <CurrentEvent>[];
  final tides = <TideEvent>[];
  var t = bc(27, 4, 43).subtract(half * 8);
  for (var i = 0; i < 6 * 7 * 4; i++) {
    final days = t.difference(bc(27, 8)).inMinutes / (24 * 60);
    final spring = math.cos(2 * math.pi * days / 14.77);
    final big = i % 4 == 0;
    final flood = (big ? 12.5 + 4.5 * spring : 4 + 2 * spring).clamp(1.5, 18.0);
    final ebb = (big ? 4 + 1.5 * spring : 11 + 3.5 * spring).clamp(1.5, 16.0);
    final isFlood = i.isEven;
    currents
      ..add(CurrentEvent(t, CurrentKind.slack, 0))
      ..add(
        CurrentEvent(
          t.add(quarter),
          isFlood ? CurrentKind.flood : CurrentKind.ebb,
          double.parse((isFlood ? flood : ebb).toStringAsFixed(1)),
        ),
      );
    tides.add(
      // Highs after the flood, lows after the ebb.
      TideEvent(
        t.add(quarter * 1.6),
        isFlood,
        isFlood ? 4.6 + spring * 0.5 : 0.8 + 1.2 * (1 - spring),
      ),
    );
    t = t.add(half);
  }
  return TidalPredictions(
    currents: currents,
    tides: tides,
    source: 'dairiki',
    tideStation: 'Egmont',
  );
}

class TidalGauges extends FakeGauges {
  TidalGauges({this.empty = false}) : super(17);
  final bool empty;

  @override
  Stream<TidalPredictions?> watchTidal(String stationId) => Stream.value(
    stationId == 'tidal_sechelt_rapids' && !empty ? skook() : null,
  );

  @override
  Stream<Map<String, StationSummary>> watchStations() => Stream.value({
    'tidal_sechelt_rapids': const StationSummary(name: 'Skookumchuck Wave'),
  });

  @override
  Future<List<FlowPoint>> dailyFlows(
    String stationId,
    int days, {
    DateTime? now,
    FlowUnit unit = FlowUnit.cms,
  }) async => const [];
}

final run = RiverRun(
  riverId: 'skookumchuck-narrows',
  name: 'Skookumchuck Narrows - Skook',
  river: 'Skookumchuck Narrows',
  province: 'BC',
  region: 'Sunshine Coast',
  difficultyClass: 'III+',
  stationId: 'tidal_sechelt_rapids',
  flowUnit: 'kt',
  source: 'Skook Surfing 101',
  sourceUrl: 'https://skooksurfing.com/surfing-skook/skook-surfing-101',
  coordinates: const {'latitude': 49.7383, 'longitude': -123.8983},
  gaugeStation: const {'name': 'Skookumchuck Wave'},
  flowRanges: const {
    'unit': 'kt',
    'low': 7,
    'medium': 10,
    'high': 15,
    'max': 18,
    'station': 'tidal_sechelt_rapids',
  },
);

Future<void> pump(
  WidgetTester tester,
  Widget screen, {
  required DateTime now,
  ThemeData? theme,
  double height = 844,
  bool empty = false,
}) async {
  tester.view.physicalSize = Size(390 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final alerts = FakeAlerts();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        riverRunsStreamProvider.overrideWith((ref) => Stream.value([run])),
        allDescentsProvider.overrideWith((ref) => Stream.value(const [])),
        favouriteRunIdsProvider.overrideWith((ref) => {'skookumchuck-narrows'}),
        setFavouritesProvider.overrideWith((ref) => (ids, on) async {}),
        gaugeRepositoryProvider.overrideWithValue(TidalGauges(empty: empty)),
        devicePositionProvider.overrideWith((ref) async => null),
        flowAlertsControllerProvider.overrideWithValue(alerts),
        alertedRunIdsProvider.overrideWith((ref) => alerts.changes.stream),
        releaseClockProvider.overrideWith((ref) => Stream.value(now)),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme ?? AppTheme.lightTheme,
        home: Scaffold(body: SafeArea(child: screen)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the gauge list shows the next max flood', (tester) async {
    await pump(tester, const GaugesScreen(), now: bc(27, 3));
    expect(find.byType(TidalGaugeRow), findsOneWidget);
    expect(find.text('Skookumchuck Wave'), findsOneWidget);
    expect(find.text('Next max flood'), findsOneWidget);
    expect(find.text('17.0'), findsOneWidget);
    expect(find.text('kt at 8a'), findsOneWidget);
    expect(find.text('Tidal'), findsOneWidget);
    expect(find.text('Too high'), findsNothing);
    expect(find.byType(FavouriteStar), findsOneWidget);
  });

  testWidgets('search finds Skook by its nicknames', (tester) async {
    await pump(tester, const GaugesScreen(), now: bc(27, 3));
    for (final q in ['skook', 'Skookumchuck', 'sechelt']) {
      await tester.enterText(find.byType(TextField), q);
      await tester.pumpAndSettle();
      expect(find.byType(TidalGaugeRow), findsOneWidget, reason: q);
    }
  });

  testWidgets('the gauge page leads with the flood and its window', (
    tester,
  ) async {
    await pump(
      tester,
      const GaugeScreen(gaugeId: 'tidal_sechelt_rapids'),
      now: bc(27, 3),
      height: 1600,
    );
    expect(find.text('Skook Surfing 101'), findsOneWidget);
    expect(find.text('Next max flood'), findsOneWidget);
    expect(find.text('17.0'), findsWidgets);
    expect(find.text('Today at 7:49 AM'), findsOneWidget);
    expect(find.text('Peaks in 4 h 49 min'), findsOneWidget);
    expect(find.text('SLACK BEFORE'), findsOneWidget);
    expect(find.text('4:43 AM'), findsOneWidget);
    expect(find.text('Flood calendar'), findsOneWidget);
    expect(find.textContaining('Today · Friday, Nov 27'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Run on this gauge'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Run on this gauge'), findsOneWidget);
  });

  testWidgets('tapping a day shows its floods', (tester) async {
    await pump(
      tester,
      const GaugeScreen(gaugeId: 'tidal_sechelt_rapids'),
      now: bc(27, 3),
      height: 1600,
    );
    await tester.tap(find.text('30').first);
    await tester.pumpAndSettle();
    expect(find.text('Monday, Nov 30'), findsOneWidget);
    expect(find.textContaining('Flood '), findsWidgets);
  });

  testWidgets('with no predictions yet, the page says so and links out', (
    tester,
  ) async {
    await pump(
      tester,
      const GaugeScreen(gaugeId: 'tidal_sechelt_rapids'),
      now: bc(27, 3),
      empty: true,
    );
    expect(find.text('No predictions yet'), findsOneWidget);
    expect(find.text('Current table on dairiki.org'), findsOneWidget);
    expect(find.text('Flood calendar'), findsNothing);
  });

  // Screenshots for review: SHOTS=1 flutter test --update-goldens
  // test/widgets/tidal_widget_test.dart
  final shots = Platform.environment['SHOTS'] == '1';
  for (final (name, screen, now, dark) in [
    ('tidal_gauges', const GaugesScreen(), bc(27, 6, 30), false),
    ('tidal_gauges_dark', const GaugesScreen(), bc(27, 6, 30), true),
    (
      'tidal_page',
      const GaugeScreen(gaugeId: 'tidal_sechelt_rapids'),
      bc(27, 6, 30),
      false,
    ),
    (
      'tidal_page_dark',
      const GaugeScreen(gaugeId: 'tidal_sechelt_rapids'),
      bc(27, 13),
      true,
    ),
  ]) {
    testWidgets('screenshot $name', skip: !shots, (tester) async {
      await tester.runAsync(loadFonts);
      await pump(
        tester,
        screen,
        now: now,
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        height: screen is GaugeScreen ? 1900 : 844,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/$name.png'),
      );
    });
  }
}
