import 'package:brownpaw/data/gauge_repository.dart';
import 'package:brownpaw/data/river_runs_repository.dart';
import 'package:brownpaw/models/river_run.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('GaugeRepository.docIdFor', () {
    test('keeps an id that is already a document id', () {
      expect(
        GaugeRepository.docIdFor('environment_canada_08mh001'),
        'environment_canada_08mh001',
      );
    });

    test('drops the Provider. prefix', () {
      expect(
        GaugeRepository.docIdFor('Provider.ENVIRONMENT_CANADA_08MH001'),
        'environment_canada_08mh001',
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
}
