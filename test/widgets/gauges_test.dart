import 'package:brownpaw/data/gauge_repository.dart';
import 'package:brownpaw/data/repositories.dart';
import 'package:brownpaw/models/descent.dart';
import 'package:brownpaw/models/realtime_flow.dart';
import 'package:brownpaw/models/river_run.dart';
import 'package:brownpaw/providers/descents_provider.dart';
import 'package:brownpaw/providers/gauges_provider.dart';
import 'package:brownpaw/providers/river_runs_provider.dart';
import 'package:brownpaw/screens/gauge_screen.dart';
import 'package:brownpaw/screens/gauges_screen.dart';
import 'package:brownpaw/theme/app_theme.dart';
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

Future<void> pumpScreen(
  WidgetTester tester,
  Widget screen, {
  Set<String> favourites = const {},
  List<Descent> descents = const [],
}) async {
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
        favouriteRunIdsProvider.overrideWithValue(favourites),
        gaugeRepositoryProvider.overrideWithValue(gauges),
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

    expect(find.text('YOUR GAUGES'), findsOneWidget);
    expect(find.text('ALL GAUGES'), findsOneWidget);
    // Both Chilliwack runs share one gauge.
    expect(find.text('Chilliwack River'), findsOneWidget);
    expect(find.text('at Vedder Crossing'), findsOneWidget);
    expect(find.text('24.6'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward), findsOneWidget);
    expect(find.text('6.1'), findsOneWidget);
    expect(find.text('Updated 13 min ago'), findsNWidgets(2));
    // Cheakamus has no station, so no gauge.
    expect(find.textContaining('Cheakamus'), findsNothing);

    final seymourY = tester.getTopLeft(find.text('Seymour River')).dy;
    final chilliwackY = tester.getTopLeft(find.text('Chilliwack River')).dy;
    expect(seymourY, lessThan(chilliwackY));
  });

  testWidgets('search finds a gauge by run name', (tester) async {
    await pumpScreen(tester, const GaugesScreen());
    expect(
      find.text('Gauges for runs you log or favourite show up here first.'),
      findsOneWidget,
    );
    await tester.enterText(find.byType(TextField), 'tamihi');
    await tester.pumpAndSettle();
    expect(find.text('1 GAUGE'), findsOneWidget);
    expect(find.text('Chilliwack River'), findsOneWidget);
    expect(find.text('Seymour River'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('NO GAUGES MATCH'), findsOneWidget);
  });

  testWidgets('gauge page shows the week and each run\'s status', (
    tester,
  ) async {
    await pumpScreen(
      tester,
      const GaugeScreen(gaugeId: 'environment_canada_08MH001'),
    );
    expect(find.text('Chilliwack River'), findsOneWidget);
    expect(find.text('24.6'), findsOneWidget);
    expect(find.text('Rising'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward), findsOneWidget);
    expect(find.text('6 days ago'), findsOneWidget);
    expect(find.text('RUNS ON THIS GAUGE'), findsOneWidget);
    expect(find.text('Tamihi to Vedder'), findsOneWidget);
    expect(find.text('Class III · good at 20 to 40'), findsOneWidget);
    expect(find.text('Good'), findsOneWidget); // Tamihi at 24.6
    expect(find.text('Canyon'), findsOneWidget);
    expect(find.text('Runnable'), findsOneWidget); // Canyon at 24.6
  });
}
