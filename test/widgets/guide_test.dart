import 'package:brownpaw/data/gauge_repository.dart';
import 'package:brownpaw/domain/guide.dart';
import 'package:brownpaw/models/river_run.dart';
import 'package:brownpaw/screens/guide_screen.dart';
import 'package:brownpaw/screens/run_details_screen.dart';
import 'package:brownpaw/widgets/map_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'gauges_test.dart';

const putIn = {'latitude': 49.0973, 'longitude': -121.9555};
const takeOut = {'latitude': 49.1067, 'longitude': -121.9952};

final guideTamihi = RiverRun(
  riverId: tamihi.riverId,
  name: tamihi.name,
  river: tamihi.river,
  province: 'BC',
  difficultyClass: 'III',
  stationId: tamihi.stationId,
  verified: true,
  minRecommendedFlow: 15,
  maxRecommendedFlow: 60,
  optimalFlowMin: 20,
  optimalFlowMax: 40,
  gaugeStation: tamihi.gaugeStation,
  putInCoordinates: putIn,
  takeOutCoordinates: takeOut,
  estimatedTime: '2-3 hours',
  putIn: 'Tamihi bridge, river left.',
  takeOut: 'Vedder Crossing, river right.',
  hazards: 'Wood below the Tamihi rapid.',
  source: 'BC Whitewater',
  sourceUrl: 'https://bcwhitewater.org/chilliwack-tamihi',
  fullText:
      'Tamihi to Vedder\n'
      'Length of Run\n: 6 km\n'
      'Special Considerations\n: Busy with rafts in summer.\n'
      'Scenery\n: Forested canyon walls.\n',
);

final guideSeymour = seymour.copyWith(
  putInCoordinates: {'latitude': 49.37, 'longitude': -122.97},
);

void main() {
  setUp(() => MapTiles.enabled = false);
  tearDown(() => MapTiles.enabled = true);

  Future<void> pumpGuide(WidgetTester tester) => pumpScreen(
    tester,
    ProviderScope(
      overrides: [
        guideEntriesProvider.overrideWith((ref) {
          final stations = {
            'environment_canada_08MH001': const StationSummary(flow: 24.6),
          };
          return AsyncValue.data(
            guideEntries([guideTamihi, canyon, guideSeymour], stations),
          );
        }),
      ],
      child: const GuideScreen(),
    ),
  );

  testWidgets('map pins open a card for the run', (tester) async {
    await pumpGuide(tester);
    expect(find.text('Running now · 2'), findsOneWidget);
    // Canyon has no coordinates, so only two pins.
    final pins = find.bySemanticsLabel(RegExp(r'^(Chilliwack|Seymour), '));
    expect(pins, findsNWidgets(2));

    await tester.tap(find.bySemanticsLabel(RegExp(r'^Chilliwack, ')));
    await tester.pumpAndSettle();
    expect(find.byType(GuideRunCard), findsOneWidget);
    expect(find.text('Tamihi to Vedder'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
  });

  testWidgets('list shows running runs first and filters', (tester) async {
    await pumpGuide(tester);
    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideRunCard), findsNWidgets(3));
    expect(find.text('Class III · 24.6 cms'), findsOneWidget);
    final canyonY = tester.getTopLeft(find.text('Canyon')).dy;
    final seymourY = tester.getTopLeft(find.text('Seymour')).dy;
    expect(canyonY, lessThan(seymourY));

    await tester.tap(find.text('Running now · 2'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideRunCard), findsNWidgets(2));
    expect(find.text('Seymour'), findsNothing);

    await tester.enterText(find.byType(TextField), 'canyon');
    await tester.pumpAndSettle();
    expect(find.byType(GuideRunCard), findsOneWidget);
  });

  testWidgets('run page shows conditions, access, hazards and the guide', (
    tester,
  ) async {
    await pumpScreen(tester, RunGuide(run: guideTamihi));
    expect(find.text('Tamihi to Vedder'), findsOneWidget);
    expect(find.text('Class III'), findsOneWidget);
    expect(find.text('6 km'), findsOneWidget);
    expect(find.text('24.6'), findsWidgets);
    // The status chip, and the band picked out on the flow guide.
    expect(find.text('Medium'), findsWidgets);
    expect(find.text('FLOW GUIDE'), findsOneWidget);
    expect(find.text('Log this run'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Put-in'), 200);
    expect(find.text('Tamihi bridge, river left.'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Wood below the Tamihi rapid.'),
      200,
    );
    expect(find.text('Busy with rafts in summer.'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('View on BC Whitewater'), 200);
    expect(find.textContaining('BC Whitewater'), findsWidgets);
  });

  testWidgets('zoom buttons and grouped pins', (tester) async {
    await pumpGuide(tester);
    expect(find.byTooltip('Zoom in'), findsOneWidget);
    expect(find.byTooltip('Zoom out'), findsOneWidget);

    // Zoomed out, Tamihi and Seymour share one marker.
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byTooltip('Zoom out'));
      await tester.pumpAndSettle();
    }
    expect(find.bySemanticsLabel('2 runs here, 1 running'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Chilliwack, ')), findsNothing);

    await tester.tap(find.byTooltip('Back to the Lower Mainland'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp(r'^Chilliwack, ')), findsOneWidget);

    // The list shows only runs in view; Canyon has no location.
    await tester.tap(find.byTooltip('List'));
    await tester.pumpAndSettle();
    expect(find.text('2 runs in the map area'), findsOneWidget);
    expect(find.byType(GuideRunCard), findsNWidgets(2));
    await tester.tap(find.text('Show all'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideRunCard), findsNWidgets(3));
  });
}
