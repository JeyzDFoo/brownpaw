import 'package:brownpaw/domain/flow_ranges.dart';
import 'package:brownpaw/domain/gauges.dart';
import 'package:brownpaw/models/realtime_flow.dart';
import 'package:brownpaw/widgets/flow_sparkline.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// One gauge's odd data (a dam holding flow flat, readings just below zero,
// NaN from the feed) must not break the screen it's on.
void main() {
  final t0 = DateTime.utc(2026, 11, 24);
  List<FlowPoint> series(List<double> flows) => [
    for (var i = 0; i < flows.length; i++)
      (time: t0.add(Duration(hours: i)), flow: flows[i]),
  ];

  final cases = <String, List<FlowPoint>>{
    'flat': series([3, 3, 3, 3]),
    'all zero': series([0, 0, 0]),
    'negative': series([-0.4, -0.2, -0.3]),
    'NaN and infinity': series([double.nan, 2, double.infinity, 3]),
    'single point': series([5]),
    'same time twice': [(time: t0, flow: 1.0), (time: t0, flow: 2.0)],
    'empty': const [],
  };

  for (final MapEntry(key: name, value: points) in cases.entries) {
    testWidgets('charts draw $name data without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                FlowSparkline(points: points),
                GaugeFlowChart(points: points, daily: false),
              ],
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('band words drop out where the bands are too thin to hold them', (
    tester,
  ) async {
    // Seymour in spate: 210 m³/s against bands at 15, 20 and 40.
    Future<Map<double, bool>> labels(List<double> flows) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GaugeFlowChart(
              points: series(flows),
              daily: false,
              height: 180,
              bands: const FlowRanges(low: 15, medium: 20, high: 40),
            ),
          ),
        ),
      );
      final data = tester.widget<LineChart>(find.byType(LineChart)).data;
      return {
        for (final l in data.extraLinesData.horizontalLines) l.y: l.label.show,
      };
    }

    // Lines stay, the word goes: Low is a 5 m³/s sliver at this scale.
    expect(await labels([30, 25, 100, 210]), {
      15.0: false,
      20.0: true,
      40.0: true,
    });
    // Near the bands there's room for every word.
    expect(await labels([18, 22, 30, 35]), {
      15.0: true,
      20.0: true,
      40.0: true,
    });
  });

  test('CSV readings drop NaN and infinity', () {
    final flow = RealtimeFlow.fromCSV(
      'datetime,discharge,level\n'
      '2026-11-24T10:00:00Z,nan,1.2\n'
      '2026-11-24T11:00:00Z,inf,\n'
      '2026-11-24T12:00:00Z,4.5,None\n',
    );
    expect(flow.readings.map((r) => r.discharge), [null, null, 4.5]);
    expect(flow.readings.first.level, 1.2);
  });
}
