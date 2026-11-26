import 'dart:async';

import 'package:brownpaw/data/gauge_repository.dart';
import 'package:brownpaw/data/repositories.dart';
import 'package:brownpaw/domain/flow_ranges.dart';
import 'package:brownpaw/domain/flow_status.dart';
import 'package:brownpaw/domain/gauges.dart';
import 'package:brownpaw/models/descent.dart';
import 'package:brownpaw/models/realtime_flow.dart';
import 'package:brownpaw/models/river_run.dart';
import 'package:brownpaw/data/push_service.dart';
import 'package:brownpaw/providers/descents_provider.dart';
import 'package:brownpaw/providers/flow_alerts_provider.dart';
import 'package:brownpaw/providers/gauges_provider.dart';
import 'package:brownpaw/providers/river_runs_provider.dart';
import 'package:brownpaw/screens/gauge_screen.dart';
import 'package:brownpaw/screens/gauges_screen.dart';
import 'package:brownpaw/theme/app_theme.dart';
import 'package:brownpaw/widgets/favourite_star.dart';
import 'package:brownpaw/widgets/flow_range_scale.dart';
import 'package:brownpaw/widgets/flow_status_chip.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'quick_log_sheet_test.dart' show FakeGauges, cheakamus;

/// Serves a week of hourly readings per station, ending [minutesAgo] ago.
class SeriesGauges extends FakeGauges {
  SeriesGauges(this.series, {this.minutesAgo = 14}) : super(null);
  final Map<String, List<double>> series;
  final int minutesAgo;

  @override
  Stream<Map<String, StationSummary>> watchStations() => Stream.value({
    'environment_canada_08GA030': const StationSummary(
      name: 'SEYMOUR RIVER NEAR NORTH VANCOUVER',
    ),
  });

  @override
  Future<List<FlowPoint>> dailyFlows(
    String stationId,
    int days, {
    DateTime? now,
    FlowUnit unit = FlowUnit.cms,
  }) async {
    final today = DateTime.now();
    return [
      for (var d = days; d >= 1; d -= 7)
        (time: today.subtract(Duration(days: d)), flow: 30.0 + d % 11),
    ];
  }

  @override
  Stream<StationRealtimeFlow?> watchCurrent(String stationId) {
    final flows = series[GaugeRepository.docIdFor(stationId)];
    if (flows == null) return Stream.value(null);
    final end = DateTime.now().subtract(Duration(minutes: minutesAgo));
    final readings = [
      for (var i = 0; i < flows.length; i++)
        FlowReading(
          timestamp: end.subtract(Duration(hours: 24 * (flows.length - 1 - i))),
          discharge: flows[i],
        ),
    ];
    // The last few hours, for the trend.
    readings.add(
      FlowReading(
        timestamp: end.add(const Duration(minutes: 1)),
        discharge: flows.last,
      ),
    );
    return Stream.value(
      StationRealtimeFlow(
        stationId: stationId,
        flow: RealtimeFlow(readings: readings),
      ),
    );
  }
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
  gaugeStation: const {'name': 'CHILLIWACK RIVER AT VEDDER CROSSING'},
);

final canyon = RiverRun(
  riverId: 'chilliwack-canyon',
  name: 'Canyon',
  river: 'Chilliwack',
  province: 'BC',
  difficultyClass: 'IV',
  stationId: 'Provider.ENVIRONMENT_CANADA_08MH001',
  verified: true,
  minRecommendedFlow: 20,
  maxRecommendedFlow: 55,
  optimalFlowMin: 25,
  optimalFlowMax: 45,
);

final seymour = RiverRun(
  riverId: 'seymour-lower',
  name: 'Lower',
  river: 'Seymour',
  province: 'BC',
  difficultyClass: 'II/III',
  stationId: '08GA030',
  verified: true,
  gaugeStation: const {'name': 'SEYMOUR RIVER NEAR NORTH VANCOUVER'},
);

final gauges = SeriesGauges({
  'environment_canada_08MH001': [18.2, 19.0, 20.7, 20.1, 21.9, 23.0, 24.6],
  'environment_canada_08GA030': [9.1, 8.6, 8.0, 7.3, 6.8, 6.4, 6.1],
});

class FakeAlerts implements FlowAlertsController {
  FakeAlerts({this.result = PushResult.enabled});
  final PushResult result;
  final on = <String>{};
  final changes = StreamController<Set<String>>.broadcast();

  @override
  Future<PushResult> turnOn(RiverRun run) async {
    if (result == PushResult.enabled) {
      on.add(run.riverId);
      changes.add({...on});
    }
    return result;
  }

  @override
  Future<void> turnOff(RiverRun run) async {
    on.remove(run.riverId);
    changes.add({...on});
  }
}

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Set<String> favourites = const {},
  List<Descent> descents = const [],
  FakeAlerts? alerts,
}) async {
  final fakeAlerts = alerts ?? FakeAlerts();
  final favs = StateProvider<Set<String>>((ref) => favourites);
  tester.view.physicalSize = const Size(390 * 3, 844 * 3);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        riverRunsStreamProvider.overrideWith(
          (ref) => Stream.value([tamihi, canyon, seymour, cheakamus]),
        ),
        allDescentsProvider.overrideWith((ref) => Stream.value(descents)),
        favouriteRunIdsProvider.overrideWith((ref) => ref.watch(favs)),
        setFavouritesProvider.overrideWith(
          (ref) => (ids, on) async {
            final n = ref.read(favs.notifier);
            n.state = on
                ? {...n.state, ...ids}
                : n.state.difference(ids.toSet());
          },
        ),
        gaugeRepositoryProvider.overrideWithValue(gauges),
        devicePositionProvider.overrideWith((ref) async => null),
        flowAlertsControllerProvider.overrideWithValue(fakeAlerts),
        alertedRunIdsProvider.overrideWith((ref) => fakeAlerts.changes.stream),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(body: screen),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists your gauges first, with flow and trend', (tester) async {
    await pumpScreen(
      tester,
      const GaugesScreen(),
      favourites: {'seymour-lower'},
    );

    expect(find.text('Starred'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    // Both Chilliwack runs share one gauge.
    expect(find.text('Chilliwack River at Vedder Crossing'), findsOneWidget);
    expect(find.text('Canyon · Tamihi to Vedder'), findsOneWidget);
    // The official name from the stations collection.
    expect(find.text('Seymour River near North Vancouver'), findsOneWidget);
    expect(find.text('24.6'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.text('6.1'), findsOneWidget);
    expect(find.text('Updated 13 min ago'), findsNWidgets(2));
    // Cheakamus has no station, so no gauge.
    expect(find.textContaining('Cheakamus'), findsNothing);

    final seymourY = tester
        .getTopLeft(find.text('Seymour River near North Vancouver'))
        .dy;
    final chilliwackY = tester
        .getTopLeft(find.text('Chilliwack River at Vedder Crossing'))
        .dy;
    expect(seymourY, lessThan(chilliwackY));
  });

  testWidgets('logged gauges sit under Recent, once each', (tester) async {
    await pumpScreen(
      tester,
      const GaugesScreen(),
      favourites: {'seymour-lower'},
      descents: [
        Descent(
          id: 'd1',
          runId: 'chilliwack-tamihi',
          runName: 'Tamihi to Vedder',
          userId: 'u',
          date: DateTime(2026, 11, 20),
          createdAt: DateTime(2026, 11, 20),
        ),
        Descent(
          id: 'd2',
          runId: 'seymour-lower',
          runName: 'Lower',
          userId: 'u',
          date: DateTime(2026, 11, 21),
          createdAt: DateTime(2026, 11, 21),
        ),
      ],
    );
    double y(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Seymour River near North Vancouver'), findsOneWidget);
    expect(find.text('Chilliwack River at Vedder Crossing'), findsOneWidget);
    expect(y('Seymour River near North Vancouver'), lessThan(y('Recent')));
    expect(y('Recent'), lessThan(y('Chilliwack River at Vedder Crossing')));
    // Its flow is in range, and the row says so.
    expect(find.byType(FlowStatusChip), findsWidgets);
  });

  testWidgets('search finds a gauge by run name', (tester) async {
    await pumpScreen(tester, const GaugesScreen());
    expect(
      find.text('Tap the star on any gauge to keep it up here.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'tamihi');
    await tester.pumpAndSettle();
    expect(find.text('1 gauge'), findsOneWidget);
    expect(find.text('Chilliwack River at Vedder Crossing'), findsOneWidget);
    expect(find.text('Seymour River near North Vancouver'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No gauges match'), findsOneWidget);
  });

  testWidgets('gauge page shows the week and each run\'s status', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const GaugeScreen(gaugeId: 'environment_canada_08MH001'),
    );
    expect(find.text('Chilliwack River at Vedder Crossing'), findsOneWidget);
    expect(find.text('24.6'), findsOneWidget);
    expect(find.text('Rising'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    // Two weeks by default; switching spans changes the range.
    expect(find.text('2 weeks ago'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    await tester.tap(find.text('2D'));
    await tester.pumpAndSettle();
    expect(find.text('2 days ago'), findsOneWidget);
    await tester.tap(find.text('1Y'));
    await tester.pumpAndSettle();
    expect(find.text('1 year ago'), findsOneWidget);
    expect(find.byType(LineChart), findsOneWidget);
    // Each run with flows can be picked; the pick drives the flow guide.
    expect(find.byType(ChoiceChip), findsNWidgets(2));
    expect(find.text('FLOW GUIDE'), findsOneWidget);
    Finder guideAt(FlowStatus status) => find.byWidgetPredicate(
      (w) => w is FlowRangeScale && w.status == status,
    );
    expect(guideAt(FlowStatus.low), findsOneWidget); // Canyon at 24.6
    await tester.tap(find.widgetWithText(ChoiceChip, 'Tamihi to Vedder'));
    await tester.pumpAndSettle();
    expect(guideAt(FlowStatus.medium), findsOneWidget); // Tamihi at 24.6

    await tester.scrollUntilVisible(
      find.text('Runs on this gauge'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Class III · Low 15 · Medium 20 · High 40 · Max 60 m³/s'),
      findsOneWidget,
    );
    Finder chipIn(String run) => find.descendant(
      of: find.ancestor(of: find.text(run), matching: find.byType(InkWell)),
      matching: find.byType(FlowStatusChip),
    );
    expect(
      find.descendant(
        of: chipIn('Tamihi to Vedder'),
        matching: find.text('Medium'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: chipIn('Canyon'), matching: find.text('Low')),
      findsOneWidget,
    );
  });

  testWidgets('the bell turns a run\'s alert on and off', (tester) async {
    final alerts = FakeAlerts();
    await pumpScreen(
      tester,
      const GaugeScreen(gaugeId: 'environment_canada_08MH001'),
      alerts: alerts,
    );
    final bell = find.byTooltip('Alert me when Tamihi to Vedder is good');
    await tester.scrollUntilVisible(
      bell,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(bell, findsOneWidget);
    await tester.ensureVisible(bell);
    await tester.pumpAndSettle();

    await tester.tap(bell);
    await tester.pumpAndSettle();
    expect(alerts.on, {'chilliwack-tamihi'});
    expect(
      find.text(
        "We'll tell you when Tamihi to Vedder is good (20 to 40 m³/s).",
      ),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.notifications_active), findsOneWidget);

    tester
        .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Turn off alert for Tamihi to Vedder'));
    await tester.pumpAndSettle();
    expect(alerts.on, isEmpty);
    expect(find.text('Alert off for Tamihi to Vedder'), findsOneWidget);
  });

  testWidgets('explains how to allow notifications when they are off', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const GaugeScreen(gaugeId: 'environment_canada_08MH001'),
      alerts: FakeAlerts(result: PushResult.denied),
    );
    await tester.scrollUntilVisible(
      find.byTooltip('Alert me when Canyon is good'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Alert me when Canyon is good'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Notifications are off for Brownpaw'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.notifications_active), findsNothing);
  });

  testWidgets('starring a gauge moves it to your gauges', (tester) async {
    await pumpScreen(tester, const GaugesScreen());
    expect(find.text('Starred'), findsOneWidget);
    final seymourBefore = tester
        .getTopLeft(find.text('Seymour River near North Vancouver'))
        .dy;
    final stars = find.byTooltip('Add gauge to favourites');
    expect(stars, findsNWidgets(2));
    await tester.tap(stars.last);
    await tester.pumpAndSettle();
    expect(find.byTooltip('Remove gauge from favourites'), findsOneWidget);
    final seymourAfter = tester
        .getTopLeft(find.text('Seymour River near North Vancouver'))
        .dy;
    expect(seymourAfter, lessThan(seymourBefore));

    await tester.tap(find.byTooltip('Remove gauge from favourites'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Add gauge to favourites'), findsNWidgets(2));
  });
}
