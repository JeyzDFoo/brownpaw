import 'package:brownpaw/domain/gauges.dart';
import 'package:brownpaw/models/descent.dart';
import 'package:brownpaw/models/realtime_flow.dart';
import 'package:brownpaw/models/river_run.dart';
import 'package:flutter_test/flutter_test.dart';

RiverRun run(
  String id,
  String river,
  String name, {
  String? station,
  String? stationName,
}) => RiverRun(
  riverId: id,
  name: name,
  river: river,
  province: 'BC',
  difficultyClass: 'III',
  stationId: station,
  gaugeStation: stationName == null ? null : {'name': stationName},
);

Descent logged(String runId, DateTime date) => Descent(
  id: '$runId$date',
  runId: runId,
  runName: runId,
  userId: 'u',
  date: date,
  createdAt: date,
);

void main() {
  group('splitStationName', () {
    test('title-cases Environment Canada names and splits the place', () {
      expect(splitStationName('CHILLIWACK RIVER AT VEDDER CROSSING'), (
        'Chilliwack River',
        'at Vedder Crossing',
      ));
      expect(splitStationName('Cheakamus River near Brackendale'), (
        'Cheakamus River',
        'near Brackendale',
      ));
    });

    test('keeps names without a place whole', () {
      expect(splitStationName('Seymour River'), ('Seymour River', ''));
    });
  });

  group('gaugesFromRuns', () {
    final tamihi = run(
      'tamihi',
      'Chilliwack',
      'Tamihi to Vedder',
      station: '08MH001',
      stationName: 'CHILLIWACK RIVER AT VEDDER CROSSING',
    );
    final canyon = run(
      'canyon',
      'Chilliwack',
      'Canyon',
      station: 'Provider.ENVIRONMENT_CANADA_08MH001',
    );
    final seymour = run('seymour', 'Seymour', 'Lower', station: '08GA030');
    final noGauge = run('x', 'Nowhere', 'Creek');

    test('groups runs that share a station, however the id is written', () {
      final gauges = gaugesFromRuns([tamihi, canyon, seymour, noGauge]);
      expect(gauges.map((g) => g.id), [
        'environment_canada_08MH001',
        'environment_canada_08GA030',
      ]);
      expect(gauges.first.river, 'Chilliwack River');
      expect(gauges.first.place, 'at Vedder Crossing');
      expect(gauges.first.runs.map((r) => r.riverId), ['canyon', 'tamihi']);
      expect(gauges.last.river, 'Seymour River');
    });

    test('yourGauges puts the most recently logged first', () {
      final gauges = gaugesFromRuns([tamihi, canyon, seymour]);
      final mine = yourGauges(
        gauges,
        favouriteRunIds: {'seymour'},
        descents: [logged('canyon', DateTime(2026, 11, 2))],
      );
      expect(mine.map((g) => g.river), ['Chilliwack River', 'Seymour River']);
      expect(yourGauges(gauges), isEmpty);
    });

    test('search matches river, place and run names', () {
      final g = gaugesFromRuns([tamihi]).single;
      expect(g.matches('vedder'), isTrue);
      expect(g.matches('tamihi'), isTrue);
      expect(g.matches('chill'), isTrue);
      expect(g.matches('seymour'), isFalse);
    });
  });

  group('trendOf', () {
    final t0 = DateTime.utc(2026, 11, 24, 12);
    List<FlowReading> series(List<double?> flows) => [
      for (var i = 0; i < flows.length; i++)
        FlowReading(
          timestamp: t0.add(Duration(hours: i)),
          discharge: flows[i],
        ),
    ];

    test('compares with the reading three hours back', () {
      expect(trendOf(series([20, 20, 21, 22, 23])), GaugeTrend.rising);
      expect(trendOf(series([30, 29, 28, 27])), GaugeTrend.falling);
      expect(trendOf(series([31, 31.2, 31.1, 31])), GaugeTrend.steady);
    });

    test('ignores readings with no discharge', () {
      expect(trendOf(series([null, 10, null])), isNull);
    });
  });

  test('updatedAgo', () {
    final now = DateTime(2026, 11, 24, 12);
    expect(
      updatedAgo(now.subtract(const Duration(minutes: 14)), now: now),
      'Updated 14 min ago',
    );
    expect(
      updatedAgo(now.subtract(const Duration(hours: 3)), now: now),
      'Updated 3 h ago',
    );
    expect(
      updatedAgo(now.subtract(const Duration(days: 4)), now: now),
      'Updated 4 days ago',
    );
  });

  test('goodRange', () {
    final r = RiverRun(
      riverId: 'r',
      name: 'n',
      river: 'r',
      province: 'BC',
      difficultyClass: 'III',
      minRecommendedFlow: 15,
      maxRecommendedFlow: 60,
      optimalFlowMin: 20,
      optimalFlowMax: 40,
    );
    expect(goodRange(r), 'good at 20 to 40');
    expect(goodRange(run('x', 'X', 'Y')), isNull);
  });
}
