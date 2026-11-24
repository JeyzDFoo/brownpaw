import 'package:brownpaw/domain/flow_lookup.dart';
import 'package:brownpaw/models/realtime_flow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('flowNearMidday', () {
    final day = DateTime(2026, 11, 20);
    FlowReading r(int hour, double? q, {int dayOffset = 0}) => FlowReading(
      timestamp: DateTime(2026, 11, 20 + dayOffset, hour),
      discharge: q,
    );

    test('picks the reading closest to noon that day', () {
      expect(flowNearMidday([r(6, 10), r(11, 20), r(15, 30)], day), 20);
    });

    test('skips readings without discharge', () {
      expect(flowNearMidday([r(12, null), r(14, 25)], day), 25);
    });

    test('ignores other days', () {
      expect(flowNearMidday([r(12, 99, dayOffset: 1)], day), isNull);
    });
  });

  group('dailyMeanOnOrBefore', () {
    final daily = <String, dynamic>{
      '2026-11-18': {'mean_discharge': 18.5},
      '2026-11-20': {'mean_discharge': 22},
    };

    test('uses the exact day', () {
      expect(dailyMeanOnOrBefore(daily, DateTime(2026, 11, 20)), 22.0);
    });

    test('falls back to the closest earlier day', () {
      expect(dailyMeanOnOrBefore(daily, DateTime(2026, 11, 19)), 18.5);
    });

    test('gives up beyond the limit', () {
      expect(
        dailyMeanOnOrBefore(daily, DateTime(2026, 12, 20), maxDaysBack: 7),
        isNull,
      );
    });
  });

  test('dateKey pads', () {
    expect(dateKey(DateTime(2026, 3, 4)), '2026-03-04');
  });
}
