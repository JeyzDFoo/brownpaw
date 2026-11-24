import 'package:brownpaw/data/gauge_repository.dart';
import 'package:brownpaw/data/river_runs_repository.dart';
import 'package:brownpaw/models/river_run.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GaugeRepository.docIdFor', () {
    test('keeps the canonical form', () {
      expect(
        GaugeRepository.docIdFor('environment_canada_08MH001'),
        'environment_canada_08MH001',
      );
      expect(
        GaugeRepository.docIdFor('metro_vancouver_capilano'),
        'metro_vancouver_capilano',
      );
    });

    test('capitalises the Environment Canada code', () {
      expect(
        GaugeRepository.docIdFor('environment_canada_08mh001'),
        'environment_canada_08MH001',
      );
    });

    test('maps the old Provider. form', () {
      expect(
        GaugeRepository.docIdFor('Provider.ENVIRONMENT_CANADA_08MH001'),
        'environment_canada_08MH001',
      );
    });

    test('prefixes a bare Environment Canada code', () {
      expect(GaugeRepository.docIdFor('08MH001'), 'environment_canada_08MH001');
    });

    test('leaves unknown formats alone', () {
      expect(GaugeRepository.docIdFor('SomethingElse'), 'SomethingElse');
    });
  });

  group('RiverRunsRepository', () {
    RiverRun run({required bool verified, String? createdBy}) => RiverRun(
      riverId: 'x',
      name: 'X',
      river: 'X',
      province: 'BC',
      difficultyClass: 'III',
      verified: verified,
      createdBy: createdBy,
    );

    test('curated runs are visible to everyone', () {
      expect(
        RiverRunsRepository.isVisibleTo(run(verified: true), null),
        isTrue,
      );
    });

    test('private runs are visible only to their creator', () {
      final mine = run(verified: false, createdBy: 'alice');
      expect(RiverRunsRepository.isVisibleTo(mine, 'alice'), isTrue);
      expect(RiverRunsRepository.isVisibleTo(mine, 'bob'), isFalse);
      expect(RiverRunsRepository.isVisibleTo(mine, null), isFalse);
    });

    test('run ids are lower-case and URL-safe', () {
      expect(
        RiverRunsRepository.runIdFor('Chilliwack', 'Tamihi to Vedder!'),
        'chilliwack-tamihi-to-vedder',
      );
    });
  });

  group('stream helpers', () {
    test('combineLatest waits for both, then follows either', () async {
      final a = StreamController<int>();
      final b = StreamController<String>();
      final out = <String>[];
      final sub = combineLatest(
        a.stream,
        b.stream,
        (x, y) => '$x$y',
      ).listen(out.add);
      a.add(1);
      await pumpEventQueue();
      expect(out, isEmpty);
      b.add('a');
      a.add(2);
      b.add('b');
      await pumpEventQueue();
      expect(out, ['1a', '2a', '2b']);
      await sub.cancel();
    });

    test('switchMap follows only the latest inner stream', () async {
      final outer = StreamController<int>();
      final inners = <int, StreamController<String>>{};
      final out = <String>[];
      final sub = switchMap(outer.stream, (int n) {
        return (inners[n] = StreamController<String>()).stream;
      }).listen(out.add);
      outer.add(1);
      await pumpEventQueue();
      inners[1]!.add('one');
      outer.add(2);
      await pumpEventQueue();
      inners[1]!.add('stale');
      inners[2]!.add('two');
      await pumpEventQueue();
      expect(out, ['one', 'two']);
      await sub.cancel();
    });
  });
}
