import 'package:flutter_test/flutter_test.dart';
import 'package:brownpaw/models/river_run.dart';

void main() {
  group('RiverRun Model Tests', () {
    test('RiverRun can be created with required fields', () {
      final run = RiverRun(
        riverId: 'test-rapid',
        name: 'Test Rapid',
        river: 'Test River',
        difficultyClass: 'Class III',
        province: 'BC',
        flowUnit: 'cms',
        putInCoordinates: const {'latitude': 49.0, 'longitude': -123.0},
        takeOutCoordinates: const {'latitude': 49.1, 'longitude': -123.1},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(run.riverId, 'test-rapid');
      expect(run.name, 'Test Rapid');
      expect(run.river, 'Test River');
      expect(run.difficultyClass, 'Class III');
      expect(run.province, 'BC');
      expect(run.flowUnit, 'cms');
    });

    test('RiverRun handles optional fields', () {
      final run = RiverRun(
        riverId: 'test-rapid',
        name: 'Test Rapid',
        river: 'Test River',
        difficultyClass: 'Class III',
        province: 'BC',
        flowUnit: 'cms',
        putInCoordinates: const {'latitude': 49.0, 'longitude': -123.0},
        takeOutCoordinates: const {'latitude': 49.1, 'longitude': -123.1},
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        description: 'A fun rapid',
        stationId: 'STATION123',
        length: '5.0 km',
        region: 'Vancouver Island',
      );

      expect(run.description, 'A fun rapid');
      expect(run.stationId, 'STATION123');
      expect(run.length, '5.0 km');
      expect(run.region, 'Vancouver Island');
    });

    test('RiverRun toMap includes all fields', () {
      final now = DateTime.now();
      final run = RiverRun(
        riverId: 'test-rapid',
        name: 'Test Rapid',
        river: 'Test River',
        difficultyClass: 'Class III',
        province: 'BC',
        flowUnit: 'cms',
        putInCoordinates: const {'latitude': 49.0, 'longitude': -123.0},
        takeOutCoordinates: const {'latitude': 49.1, 'longitude': -123.1},
        updatedAt: now,
        description: 'A fun rapid',
      );

      final map = run.toMap();

      expect(map['riverId'], 'test-rapid');
      expect(map['name'], 'Test Rapid');
      expect(map['river'], 'Test River');
      expect(map['difficultyClass'], 'Class III');
      expect(map['province'], 'BC');
      expect(map['description'], 'A fun rapid');
      expect(map['flowUnit'], 'cms');
    });
  });
}
