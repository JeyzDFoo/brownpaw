import 'package:brownpaw/data/gauge_repository.dart';
import 'package:brownpaw/domain/flow_ranges.dart';
import 'package:brownpaw/domain/gauges.dart';
import 'package:brownpaw/data/repositories.dart';
import 'package:brownpaw/models/descent.dart';
import 'package:brownpaw/models/river_run.dart';
import 'package:brownpaw/providers/descents_provider.dart';
import 'package:brownpaw/providers/river_runs_provider.dart';
import 'package:brownpaw/theme/app_theme.dart';
import 'package:brownpaw/domain/dam_release.dart';
import 'package:brownpaw/domain/tidal.dart';
import 'package:brownpaw/widgets/quick_log_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeGauges implements GaugeRepository {
  FakeGauges(this.flow);
  final double? flow;
  final asked = <String>[];

  @override
  Future<double?> flowOn(
    String stationId,
    DateTime day, {
    DateTime? now,
  }) async {
    asked.add(stationId);
    return flow;
  }

  @override
  Future<StationRealtimeFlow?> getCurrent(String stationId) async => null;

  @override
  Stream<ReleaseSchedule?> watchReleaseSchedule(String stationId) =>
      Stream.value(null);

  @override
  Stream<TidalPredictions?> watchTidal(String stationId) => Stream.value(null);

  @override
  Stream<StationRealtimeFlow?> watchCurrent(String stationId) =>
      Stream.value(null);

  /// The fakes have no live source: the stored series is what's live.
  @override
  Stream<StationRealtimeFlow?> watchLive(String stationId) =>
      watchCurrent(stationId);

  @override
  Stream<Map<String, StationSummary>> watchStations() => Stream.value(const {});

  @override
  Future<List<FlowPoint>> dailyFlows(
    String stationId,
    int days, {
    DateTime? now,
    FlowUnit unit = FlowUnit.cms,
  }) async => const [];
}

final tamihi = RiverRun(
  riverId: 'chilliwack-tamihi',
  name: 'Tamihi to Vedder',
  river: 'Chilliwack',
  province: 'BC',
  difficultyClass: 'III',
  stationId: '08MH001',
  verified: true,
  minRecommendedFlow: 15,
  maxRecommendedFlow: 60,
  optimalFlowMin: 20,
  optimalFlowMax: 40,
  gaugeStation: const {'name': 'Chilliwack River at Vedder Crossing'},
);

final cheakamus = RiverRun(
  riverId: 'cheakamus-lower',
  name: 'Lower',
  river: 'Cheakamus',
  province: 'BC',
  difficultyClass: 'II+',
  verified: true,
);

final lastTrip = Descent(
  id: 'd1',
  runId: 'chilliwack-tamihi',
  runName: 'Chilliwack - Tamihi to Vedder',
  userId: 'u',
  date: DateTime(2026, 11, 9),
  crew: const ['Sam', 'Alex'],
  createdAt: DateTime(2026, 11, 9),
);

final olderTrip = Descent(
  id: 'd0',
  runId: 'cheakamus-lower',
  runName: 'Cheakamus - Lower',
  userId: 'u',
  date: DateTime(2026, 11, 2),
  crew: const ['Sam', 'Priya'],
  createdAt: DateTime(2026, 11, 2),
);

Future<FakeGauges> pumpSheet(
  WidgetTester tester, {
  RiverRun? run,
  double? flow = 24.6,
}) async {
  SharedPreferences.setMockInitialValues({});
  final gauges = FakeGauges(flow);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        allDescentsProvider.overrideWith(
          (ref) => Stream.value([lastTrip, olderTrip]),
        ),
        riverRunsStreamProvider.overrideWith(
          (ref) => Stream.value([tamihi, cheakamus]),
        ),
        gaugeRepositoryProvider.overrideWithValue(gauges),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: QuickLogSheet(initialRun: run)),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return gauges;
}

void main() {
  testWidgets('fills in the last run, today, gauge flow and last crew', (
    tester,
  ) async {
    final gauges = await pumpSheet(tester);

    expect(find.text('Tamihi to Vedder'), findsOneWidget);
    expect(find.textContaining('Your last logged run'), findsOneWidget);
    expect(find.textContaining('Today'), findsOneWidget);
    expect(find.text('24.6 m³/s'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(
      find.text('Filled in from Chilliwack River at Vedder Crossing.'),
      findsOneWidget,
    );
    expect(gauges.asked, ['08MH001']);

    FilterChip chip(String name) =>
        tester.widget(find.widgetWithText(FilterChip, name));
    expect(chip('Sam').selected, isTrue);
    expect(chip('Alex').selected, isTrue);
    expect(chip('Priya').selected, isFalse);

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Save to logbook'),
    );
    expect(save.onPressed, isNotNull);
  });

  testWidgets('a run passed in wins over the suggestion', (tester) async {
    await pumpSheet(tester, run: cheakamus);
    expect(find.text('Lower'), findsOneWidget);
    expect(find.textContaining('Your last logged run'), findsNothing);
    expect(
      find.text('This run has no gauge. Add flow if you know it.'),
      findsOneWidget,
    );
  });

  testWidgets('says so when the gauge has no reading', (tester) async {
    await pumpSheet(tester, flow: null);
    expect(find.text('Add'), findsWidgets);
    expect(
      find.text('No gauge reading for this day. Add flow if you know it.'),
      findsOneWidget,
    );
  });

  testWidgets('tapping a crew chip toggles it', (tester) async {
    await pumpSheet(tester);
    await tester.tap(find.widgetWithText(FilterChip, 'Priya'));
    await tester.pump();
    final chip = tester.widget<FilterChip>(
      find.widgetWithText(FilterChip, 'Priya'),
    );
    expect(chip.selected, isTrue);
  });
}
