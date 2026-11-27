import 'dart:io';

import 'package:brownpaw/data/gauge_repository.dart';
import 'package:brownpaw/data/repositories.dart';
import 'package:brownpaw/domain/dam_release.dart';
import 'package:brownpaw/domain/flow_ranges.dart';
import 'package:brownpaw/domain/gauges.dart';
import 'package:brownpaw/models/realtime_flow.dart';
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
import 'package:brownpaw/widgets/release_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gauges_test.dart' show FakeAlerts;
import 'quick_log_sheet_test.dart' show FakeGauges;

DateTime alberta(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour + 6, minute);

/// Barrier as published: 28 m³/s from 5 PM to 11 PM Alberta, five days,
/// with Monday off and Tuesday at 21.
List<ReleaseHour> barrierHours() => [
  for (var h = 0; h < 24 * 5; h++)
    (
      start: alberta(27, 0).add(Duration(hours: h)),
      flow: switch ((h ~/ 24, h % 24)) {
        (3, _) => 0.0,
        (4, final hr) when hr >= 17 && hr <= 22 => 21.0,
        (_, final hr) when hr >= 17 && hr <= 22 => 28.0,
        _ => 0.0,
      },
    ),
];

class ReleaseGauges extends FakeGauges {
  ReleaseGauges(this.now) : super(28);
  final DateTime now;

  @override
  Stream<ReleaseSchedule?> watchReleaseSchedule(String stationId) =>
      Stream.value(
        stationId == 'transalta_barrier'
            ? ReleaseSchedule(barrierHours())
            : null,
      );

  @override
  Stream<Map<String, StationSummary>> watchStations() => Stream.value({
    'transalta_barrier': const StationSummary(
      name: 'Barrier Dam release',
      note: 'Water takes about 45 minutes from Barrier Dam to Canoe Meadows.',
    ),
  });

  @override
  Future<List<FlowPoint>> dailyFlows(
    String stationId,
    int days, {
    DateTime? now,
    FlowUnit unit = FlowUnit.cms,
  }) async => const [];

  /// Two weeks of evening releases.
  @override
  Stream<StationRealtimeFlow?> watchLive(String stationId) {
    final readings = <FlowReading>[];
    for (
      var t = now.subtract(const Duration(days: 14));
      t.isBefore(now);
      t = t.add(const Duration(hours: 1))
    ) {
      final hr = riverWall(t).hour;
      readings.add(
        FlowReading(timestamp: t, discharge: hr >= 17 && hr <= 22 ? 28 : 0),
      );
    }
    return Stream.value(
      StationRealtimeFlow(
        stationId: stationId,
        flow: RealtimeFlow(readings: readings),
      ),
    );
  }

  @override
  Stream<StationRealtimeFlow?> watchCurrent(String stationId) =>
      watchLive(stationId);
}

const ranges = {
  'unit': 'cms',
  'low': 20,
  'medium': 25,
  'high': 35,
  'max': 50,
  'station': 'transalta_barrier',
};

RiverRun kan(String id, String name, String grade) => RiverRun(
  riverId: id,
  name: 'Kananaskis River - $name',
  river: 'Kananaskis River',
  province: 'AB',
  region: 'Kananaskis Country',
  difficultyClass: grade,
  stationId: 'transalta_barrier',
  flowRanges: ranges,
  gaugeStation: const {'name': 'Barrier Dam release'},
);

final upper = kan('kananaskis-upper', 'Upper Kan', 'III');
final middle = kan('kananaskis-middle', 'Middle Kan (Racecourse)', 'III');
final lower = kan('kananaskis-lower', 'Lower Kan', 'II');

Future<void> pump(
  WidgetTester tester,
  Widget screen, {
  required DateTime now,
  ThemeData? theme,
  double height = 844,
}) async {
  tester.view.physicalSize = Size(390 * 3, height * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final alerts = FakeAlerts();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        riverRunsStreamProvider.overrideWith(
          (ref) => Stream.value([upper, middle, lower]),
        ),
        allDescentsProvider.overrideWith((ref) => Stream.value(const [])),
        favouriteRunIdsProvider.overrideWith((ref) => {'kananaskis-upper'}),
        setFavouritesProvider.overrideWith((ref) => (ids, on) async {}),
        gaugeRepositoryProvider.overrideWithValue(ReleaseGauges(now)),
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

Future<void> loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  Future<void> load(String family, List<String> paths) async {
    final loader = FontLoader(family);
    for (final p in paths) {
      final bytes = File(p).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }

  await load('Nunito', [
    for (final w in [500, 600, 700, 800, 900]) 'fonts/Nunito-$w.ttf',
  ]);
  if (flutterRoot != null) {
    await load('MaterialIcons', [
      '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    ]);
  }
}

void main() {
  testWidgets('the gauge list shows the next release, not a live reading', (
    tester,
  ) async {
    await pump(tester, const GaugesScreen(), now: alberta(27, 16, 40));
    expect(find.byType(ReleaseGaugeRow), findsOneWidget);
    expect(find.text('Barrier Dam release'), findsOneWidget);
    expect(find.text('Next release today'), findsOneWidget);
    expect(find.text('5 PM–11 PM'), findsOneWidget);
    expect(find.text('m³/s at 5 PM'), findsOneWidget);
    expect(find.text('Dam release'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.byType(FavouriteStar), findsOneWidget);
  });

  testWidgets('while releasing, the row says until when', (tester) async {
    await pump(tester, const GaugesScreen(), now: alberta(27, 19, 15));
    expect(find.text('Releasing until 11 PM'), findsOneWidget);
    expect(find.text('m³/s now'), findsOneWidget);
  });

  testWidgets('the gauge page lists the schedule a day per row', (
    tester,
  ) async {
    await pump(
      tester,
      const GaugeScreen(gaugeId: 'transalta_barrier'),
      now: alberta(27, 16, 40),
    );
    expect(find.text('Next release today'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Tomorrow'), findsOneWidget);
    expect(find.text('No release'), findsOneWidget);
    expect(find.text('5 PM–11 PM · 21 m³/s'), findsOneWidget);
    expect(find.textContaining('45 minutes'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Runs on this gauge'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Past releases'), findsOneWidget);
    expect(find.text('Runs on this gauge'), findsOneWidget);
  });

  // Screenshots for review: SHOTS=1 flutter test --update-goldens
  // test/widgets/dam_release_widget_test.dart
  final shots = Platform.environment['SHOTS'] == '1';
  for (final (name, screen, now, dark) in [
    ('gauges_next', const GaugesScreen(), alberta(27, 16, 40), false),
    ('gauges_releasing', const GaugesScreen(), alberta(27, 19, 15), false),
    ('gauges_dark', const GaugesScreen(), alberta(27, 19, 15), true),
    (
      'gauge_page',
      const GaugeScreen(gaugeId: 'transalta_barrier'),
      alberta(27, 16, 40),
      false,
    ),
    (
      'gauge_page_dark',
      const GaugeScreen(gaugeId: 'transalta_barrier'),
      alberta(27, 19, 15),
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
        height: screen is GaugeScreen ? 1500 : 844,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('shots/$name.png'),
      );
    });
  }
}
