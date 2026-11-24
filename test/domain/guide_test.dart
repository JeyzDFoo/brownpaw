import 'package:brownpaw/data/gauge_repository.dart';
import 'package:brownpaw/domain/flow_status.dart';
import 'package:brownpaw/domain/guide.dart';
import 'package:brownpaw/domain/run_guide.dart';
import 'package:brownpaw/models/river_run.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

RiverRun run(
  String id,
  String river, {
  String? station,
  Map<String, double>? putIn,
  Map<String, double>? at,
  double? min,
  double? max,
}) => RiverRun(
  riverId: id,
  name: id,
  river: river,
  province: 'BC',
  difficultyClass: 'III',
  stationId: station,
  putInCoordinates: putIn,
  coordinates: at,
  minRecommendedFlow: min,
  maxRecommendedFlow: max,
);

void main() {
  group('guideSections', () {
    test('reads headings followed by a colon line', () {
      const text =
          'Cheakamus River\n'
          'Length of Run\n: 6 km\n'
          'Length of Shuttle\n(one way): 4 km\n'
          'Special Considerations\n: Wood after storms.\n'
          'Scenery\n:\n';
      final s = guideSections(text);
      expect(s['length of run'], '6 km');
      expect(s['length of shuttle'], '4 km');
      expect(s['special considerations'], 'Wood after storms.');
      // Empty bodies are left out.
      expect(s.containsKey('scenery'), isFalse);
    });

    test('is empty with no text', () {
      expect(guideSections(null), isEmpty);
      expect(guideSections(''), isEmpty);
    });
  });

  group('directionsUri', () {
    test('Apple Maps on iOS', () {
      final uri = directionsUri(49.1, -122.0, platform: TargetPlatform.iOS);
      expect(uri.host, 'maps.apple.com');
      expect(uri.queryParameters['daddr'], '49.1,-122.0');
    });

    test('Google Maps elsewhere', () {
      final uri = directionsUri(49.1, -122.0, platform: TargetPlatform.android);
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['destination'], '49.1,-122.0');
    });
  });

  group('guideEntries', () {
    final stations = {
      'environment_canada_08MH001': const StationSummary(flow: 30),
      'environment_canada_08GA030': const StationSummary(flow: 2),
    };

    test('uses the latest station flow for status, running first', () {
      final entries = guideEntries([
        run('low', 'Seymour', station: '08GA030', min: 5, max: 20),
        run('none', 'Alouette'),
        run(
          'good',
          'Chilliwack',
          station: 'Provider.ENVIRONMENT_CANADA_08MH001',
          min: 15,
          max: 60,
        ),
      ], stations);
      expect(entries.map((e) => e.run.riverId), ['good', 'none', 'low']);
      expect(entries.first.flow, 30);
      expect(entries.first.status, FlowStatus.runnable);
      expect(entries.last.status, FlowStatus.tooLow);
      expect(entries[1].status, FlowStatus.unknown);
    });

    test('pins at the put-in, else the run coordinates', () {
      final entries = guideEntries([
        run(
          'a',
          'A',
          putIn: {'latitude': 49.1, 'longitude': -121.9},
          at: {'latitude': 1, 'longitude': 1},
        ),
        run('b', 'B', at: {'latitude': 49.7, 'longitude': -123.1}),
        run('c', 'C'),
      ], const {});
      expect((entries[0].latitude, entries[0].longitude), (49.1, -121.9));
      expect((entries[1].latitude, entries[1].longitude), (49.7, -123.1));
      expect(entries[2].onMap, isFalse);
    });

    test('search matches river, run and class', () {
      final e = guideEntries([run('canyon', 'Chilliwack')], const {}).single;
      expect(e.matches('chilli'), isTrue);
      expect(e.matches('CANYON'), isTrue);
      expect(e.matches('iii'), isTrue);
      expect(e.matches('seymour'), isFalse);
    });
  });

  test('a group shows its best status', () {
    final entries = guideEntries(
      [
        run('low', 'A', station: '08GA030', min: 5),
        run('good', 'B', station: '08MH001', min: 15, max: 60),
        run('none', 'C'),
      ],
      {
        'environment_canada_08MH001': const StationSummary(flow: 30),
        'environment_canada_08GA030': const StationSummary(flow: 2),
      },
    );
    expect(bestStatus(entries), FlowStatus.runnable);
    expect(
      bestStatus(entries.where((e) => e.run.riverId != 'good')),
      FlowStatus.tooLow,
    );
    expect(bestStatus(const []), FlowStatus.unknown);
  });
}
