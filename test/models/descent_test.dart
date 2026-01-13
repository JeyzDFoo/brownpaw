import 'package:flutter_test/flutter_test.dart';
import 'package:brownpaw/models/descent.dart';

void main() {
  group('Descent Model Tests', () {
    test('Descent can be created with required fields', () {
      final descent = Descent(
        id: 'descent-123',
        userId: 'user-456',
        runId: 'run-789',
        runName: 'Test Run',
        date: DateTime(2026, 1, 12),
        createdAt: DateTime.now(),
        isPublic: false,
      );

      expect(descent.id, 'descent-123');
      expect(descent.userId, 'user-456');
      expect(descent.runId, 'run-789');
      expect(descent.runName, 'Test Run');
      expect(descent.isPublic, false);
    });

    test('Descent handles optional fields', () {
      final descent = Descent(
        id: 'descent-123',
        userId: 'user-456',
        runId: 'run-789',
        runName: 'Test Run',
        date: DateTime(2026, 1, 12),
        createdAt: DateTime.now(),
        isPublic: true,
        flow: 50.5,
        flowUnit: 'cms',
        notes: 'Great day on the water!',
        rating: 4,
        difficulty: 'Class III',
      );

      expect(descent.flow, 50.5);
      expect(descent.flowUnit, 'cms');
      expect(descent.notes, 'Great day on the water!');
      expect(descent.rating, 4);
      expect(descent.difficulty, 'Class III');
      expect(descent.isPublic, true);
    });

    test('Descent stores flow data correctly', () {
      final descent = Descent(
        id: 'test',
        userId: 'user',
        runId: 'run',
        runName: 'Test Run',
        date: DateTime.now(),
        createdAt: DateTime.now(),
        isPublic: false,
        flow: 42.3,
        flowUnit: 'cms',
      );

      expect(descent.flow, 42.3);
      expect(descent.flowUnit, 'cms');
    });

    test('Descent rating is validated', () {
      // Valid ratings
      expect(
        () => Descent(
          id: 'test',
          userId: 'user',
          runId: 'run',
          runName: 'Run',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          isPublic: false,
          rating: 5,
        ),
        returnsNormally,
      );

      expect(
        () => Descent(
          id: 'test',
          userId: 'user',
          runId: 'run',
          runName: 'Run',
          date: DateTime.now(),
          createdAt: DateTime.now(),
          isPublic: false,
          rating: 1,
        ),
        returnsNormally,
      );
    });
  });
}
