import 'package:brownpaw/data/gauge_repository.dart';
import 'package:brownpaw/domain/flow_status.dart';
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
  test('stationTitle title-cases Environment Canada names', () {
    expect(
      stationTitle('CHEAKAMUS RIVER ABOVE MILLAR CREEK'),
      'Cheakamus River above Millar Creek',
    );
    expect(
      stationTitle('Clearwater River near Clearwater Station'),
      'Clearwater River near Clearwater Station',
    );
  });

  test('runLabel drops the river in front', () {
    expect(
      runLabel(run('a', 'Clearwater River', 'Clearwater River - Upper')),
      'Upper',
    );
    expect(
      runLabel(run('b', 'Cheakamus', 'Cheakamus – Paradise Valley')),
      'Paradise Valley',
    );
    expect(runLabel(run('c', 'Elaho', 'Elaho-Squamish')), 'Elaho-Squamish');
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
      expect(gauges.first.title, 'Chilliwack River at Vedder Crossing');
      expect(gauges.first.place, 'Canyon · Tamihi to Vedder');
      expect(gauges.first.runs.map((r) => r.riverId), ['canyon', 'tamihi']);
      expect(gauges.last.title, 'Seymour River');
    });

    test('yourGauges puts the most recently logged first', () {
      final gauges = gaugesFromRuns([tamihi, canyon, seymour]);
      final mine = yourGauges(
        gauges,
        favouriteRunIds: {'seymour'},
        descents: [logged('canyon', DateTime(2026, 11, 2))],
      );
      expect(mine.map((g) => g.title), [
        'Chilliwack River at Vedder Crossing',
        'Seymour River',
      ]);
      expect(yourGauges(gauges), isEmpty);
    });

    test('ignores stray flow readings stored as station names', () {
      expect(isStationName('96.4cms↓'), isFalse);
      expect(isStationName('1.875m↓'), isFalse);
      expect(isStationName('CHEAKAMUS RIVER NEAR BRACKENDALE'), isTrue);
      final g = gaugesFromRuns([
        run(
          'pv',
          'Cheakamus',
          'Paradise Valley',
          station: '08GA043',
          stationName: '96.4cms↓',
        ),
        run('dam', 'Cheakamus', 'Dam Run', station: '08GA043'),
      ]).single;
      expect(g.title, 'Cheakamus River');
      expect(g.place, 'Dam Run · Paradise Valley');
    });

    test('official station names win, and odd river fields are tidied', () {
      final gauges = gaugesFromRuns(
        [
          run(
            'gg',
            'Clearwater River - Gatling Gorge',
            'Gatling Gorge',
            station: '08LA001',
          ),
          run(
            'chw',
            ': Check the Chilliwack',
            'Check the Chilliwack',
            station: '08MH016',
          ),
        ],
        stationNames: {
          'environment_canada_08LA001':
              'CLEARWATER RIVER NEAR CLEARWATER STATION',
        },
      );
      expect(gauges.map((g) => g.title), [
        'Check the Chilliwack River',
        'Clearwater River near Clearwater Station',
      ]);
    });

    test('search matches river, place and run names', () {
      final g = gaugesFromRuns([tamihi]).single;
      expect(g.matches('vedder'), isTrue);
      expect(g.matches('tamihi'), isTrue);
      expect(g.matches('chill'), isTrue);
      expect(g.matches('seymour'), isFalse);
    });
  });

  group('gaugeSource', () {
    test('credits the publisher by station id', () {
      expect(gaugeSource('environment_canada_08GA012'), 'Environment Canada');
      expect(gaugeSource('metro_vancouver_seymour'), 'Metro Vancouver');
      expect(gaugeSource('flowworks_lynn'), 'District of North Vancouver');
      expect(gaugeSource('somewhere_else'), '');
    });
  });

  test('a Metro Vancouver run gets its own gauge', () {
    final gauges = gaugesFromRuns(
      [
        run(
          'capilano-river',
          'Capilano River',
          'Capilano',
          station: 'metro_vancouver_capilano',
        ),
      ],
      stationNames: {
        'metro_vancouver_capilano': 'Capilano River below Cleveland Dam',
      },
    );
    expect(gauges.single.id, 'metro_vancouver_capilano');
    expect(gauges.single.title, 'Capilano River below Cleveland Dam');
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

  test('hourlyWindow keeps readings within the span of the latest', () {
    final end = DateTime.utc(2026, 11, 24);
    final readings = [
      for (var d = 10; d >= 0; d--)
        FlowReading(
          timestamp: end.subtract(Duration(days: d)),
          discharge: d.toDouble(),
        ),
    ];
    expect(hourlyWindow(readings, 2).map((p) => p.flow), [2, 1, 0]);
  });

  test('dailySeries reads daily means in range, oldest first', () {
    final points = dailySeries(
      [
        {
          '2026-01-02': {'mean_discharge': 12.5},
          '2026-01-01': {'mean_discharge': 10},
          '2025-12-01': {'mean_discharge': 99},
          'bad': {'mean_discharge': 1},
        },
      ],
      DateTime(2025, 12, 20),
      DateTime(2026, 1, 5),
    );
    expect(points.map((p) => p.flow), [10, 12.5]);
  });

  test('rangeSummary', () {
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
    expect(rangeSummary(r), 'Low 15 · Medium 20 · High 40 · Max 60 m³/s');
    expect(rangeSummary(run('x', 'X', 'Y')), isNull);
  });

  test('new paddlers start with Capilano, Lynn Creek and the Mamquam', () {
    final runs = [
      run(
        'capilano-river',
        'Capilano River',
        'Capilano River',
        station: 'metro_vancouver_capilano',
      ),
      run('lynn-creek', 'Lynn Creek', 'Lynn Creek', station: 'flowworks_lynn'),
      run(
        'lower-mamquam',
        'Lower Mamquam',
        'Mamquam River',
        station: '08GA075',
      ),
      run(
        'cheakamus',
        'Paradise Valley',
        'Cheakamus River',
        station: '08GA043',
      ),
    ];
    expect(starterFavouriteRunIds(runs), {
      'capilano-river',
      'lynn-creek',
      'lower-mamquam',
    });
  });

  group('gaugeSections', () {
    final now = DateTime(2026, 11, 26, 12);
    RiverRun ranged(
      String id,
      String station, {
      required double lat,
      required double lng,
      double low = 10,
    }) => RiverRun(
      riverId: id,
      name: id,
      river: id,
      province: 'BC',
      difficultyClass: 'III',
      stationId: station,
      gaugeStation: {'name': '${id.toUpperCase()} RIVER GAUGE'},
      flowRanges: {'low': low, 'medium': low * 2, 'high': low * 4},
      putInCoordinates: {'latitude': lat, 'longitude': lng},
    );

    // Vancouver-ish, and runs north, east and far east of it.
    const home = (latitude: 49.28, longitude: -123.12);
    final near = ranged('near', '08AA001', lat: 49.35, lng: -123.10);
    final mid = ranged('mid', '08AA002', lat: 49.70, lng: -123.15);
    final far = ranged('far', '08AA003', lat: 49.38, lng: -121.44);
    final noRange = run('blank', 'Blank', 'Blank', station: '08AA004');
    final gauges = gaugesFromRuns([near, mid, far, noRange]);

    StationSummary at(double flow, {Duration age = Duration.zero}) =>
        StationSummary(flow: flow, readingTime: now.subtract(age));

    test('puts running gauges first, then nearest, then by name', () {
      final s = gaugeSections(
        gauges,
        stations: {
          'environment_canada_08AA001': at(5), // too low
          'environment_canada_08AA002': at(25),
          'environment_canada_08AA003': at(15),
          'environment_canada_08AA004': at(99), // no range
        },
        position: home,
        now: now,
      );
      expect(s.all.map((g) => g.runs.first.riverId), [
        'mid',
        'far',
        'near',
        'blank',
      ]);
    });

    test('falls back to name order without a location', () {
      final s = gaugeSections(
        gauges,
        stations: {
          'environment_canada_08AA003': at(15),
          'environment_canada_08AA002': at(25),
        },
        now: now,
      );
      expect(s.all.map((g) => g.runs.first.riverId), [
        'far',
        'mid',
        'blank',
        'near',
      ]);
    });

    test('a day-old reading does not count as running', () {
      final g = gauges.firstWhere((g) => g.runs.first.riverId == 'mid');
      expect(gaugeStatus(g, at(25), now: now), FlowStatus.medium);
      expect(
        gaugeStatus(g, at(25, age: const Duration(hours: 30)), now: now),
        FlowStatus.unknown,
      );
    });

    test('splits starred, logged and the rest without repeats', () {
      final s = gaugeSections(
        gauges,
        favouriteRunIds: {'far'},
        descents: [logged('far', now), logged('near', now)],
        now: now,
      );
      expect(s.starred.map((g) => g.runs.first.riverId), ['far']);
      expect(s.recent.map((g) => g.runs.first.riverId), ['near']);
      expect(s.all.map((g) => g.runs.first.riverId), ['blank', 'mid']);
    });

    test('distance labels', () {
      expect(distanceLabel(0.4), 'Under 1 km away');
      expect(distanceLabel(3.26), '3.3 km away');
      expect(distanceLabel(42.6), '43 km away');
      final g = gauges.firstWhere((g) => g.runs.first.riverId == 'near');
      expect(gaugeDistanceKm(g, home), closeTo(7.9, 0.3));
    });
  });
}
