import 'package:brownpaw/data/bc_flow_ranges.dart';
import 'package:brownpaw/domain/flow_ranges.dart';
import 'package:brownpaw/domain/flow_status.dart';
import 'package:brownpaw/models/river_run.dart';
import 'package:flutter_test/flutter_test.dart';

RiverRun run({
  String id = 'r',
  String name = 'Run',
  String? station = 'environment_canada_08GA043',
  Map<String, dynamic>? flowRanges,
  double? min,
  double? max,
  double? optMin,
  double? optMax,
}) => RiverRun(
  riverId: id,
  name: name,
  river: name,
  province: 'BC',
  difficultyClass: 'III',
  stationId: station,
  flowRanges: flowRanges,
  minRecommendedFlow: min,
  maxRecommendedFlow: max,
  optimalFlowMin: optMin,
  optimalFlowMax: optMax,
);

void main() {
  FlowStatus eval(
    double? v, {
    double? low,
    double? medium,
    double? high,
    double? max,
  }) => FlowStatus.evaluate(
    FlowRanges(low: low, medium: medium, high: high, max: max),
    v,
  );

  group('FlowStatus.evaluate', () {
    test('unknown without a reading or any numbers', () {
      expect(eval(null, low: 10), FlowStatus.unknown);
      expect(eval(double.nan, low: 10), FlowStatus.unknown);
      expect(eval(20), FlowStatus.unknown);
      expect(FlowStatus.evaluate(null, 20), FlowStatus.unknown);
    });

    test('low / medium / high: each number is where its level starts', () {
      FlowStatus cheak(double v) => eval(v, low: 25, medium: 50, high: 100);
      expect(cheak(24.9), FlowStatus.tooLow);
      expect(cheak(25), FlowStatus.low);
      expect(cheak(49), FlowStatus.low);
      expect(cheak(50), FlowStatus.medium);
      expect(cheak(99), FlowStatus.medium);
      expect(cheak(100), FlowStatus.high);
      expect(cheak(400), FlowStatus.high);
    });

    test('a maximum caps high', () {
      expect(
        eval(250, low: 60, medium: 80, high: 150, max: 200),
        FlowStatus.tooHigh,
      );
      expect(
        eval(180, low: 60, medium: 80, high: 150, max: 200),
        FlowStatus.high,
      );
    });

    test('low and high with no medium: medium between', () {
      expect(eval(10, low: 16, high: 32), FlowStatus.tooLow);
      expect(eval(20, low: 16, high: 32), FlowStatus.medium);
      expect(eval(40, low: 16, high: 32), FlowStatus.high);
    });

    test('no low: below medium is low, not too low', () {
      expect(eval(1, medium: 2.5, high: 3), FlowStatus.low);
      expect(eval(2.6, medium: 2.5, high: 3), FlowStatus.medium);
    });

    test('only an upper bound', () {
      expect(eval(60, max: 80), FlowStatus.medium);
      expect(eval(90, max: 80), FlowStatus.tooHigh);
      expect(eval(60, high: 80), FlowStatus.unknown);
    });
  });

  test('labels use the guidebook words', () {
    expect(FlowStatus.tooLow.label, 'Too low');
    expect(FlowStatus.low.label, 'Low');
    expect(FlowStatus.medium.label, 'Medium');
    expect(FlowStatus.high.label, 'High');
    expect(FlowStatus.medium.isRunnable, isTrue);
    expect(FlowStatus.tooHigh.isRunnable, isFalse);
    expect(FlowStatus.tooLow.isRunnable, isFalse);
  });

  group('run flows', () {
    test('bundled BC Whitewater numbers, found by id', () {
      final r = run(id: 'cheakamus-paradise-valley');
      expect(r.ranges?.summary, 'Low 25 · Medium 50 · High 100 m³/s');
      expect(r.ranges?.source, 'BC Whitewater');
      expect(r.flowStatus(60), FlowStatus.medium);
    });

    test('bundled numbers found by name when the id differs', () {
      final r = run(id: 'abc123', name: 'Cheakamus – Paradise Valley');
      expect(r.ranges?.medium, 50);
    });

    test('metres runs are judged on level, not discharge', () {
      final r = run(
        id: 'cheakamus-river-upper',
        station: 'environment_canada_08GA072',
      );
      expect(r.ranges?.unit, FlowUnit.metres);
      expect(r.flowStatus(30), FlowStatus.unknown);
      expect(r.flowStatus(30, level: 2.6), FlowStatus.medium);
      expect(r.flowStatus(30, level: 2.0), FlowStatus.tooLow);
    });

    test('numbers on another gauge are a reference only', () {
      final elsewhere = run(
        id: 'cheakamus-paradise-valley',
        station: 'environment_canada_08MH001',
      );
      expect(elsewhere.ranges, isNotNull);
      expect(elsewhere.hasFlowRanges, isFalse);
      expect(elsewhere.flowStatus(60), FlowStatus.unknown);
      final offline = run(id: 'callaghan-creek', station: null);
      expect(offline.ranges?.gauge, isNotNull);
      expect(offline.flowStatus(1, level: 0.3), FlowStatus.unknown);
    });

    test('numbers stored on the run win over the bundled ones', () {
      final r = run(
        id: 'cheakamus-paradise-valley',
        flowRanges: {'low': 30, 'medium': 60, 'high': 120},
      );
      expect(r.ranges?.low, 30);
    });

    test('older min / optimal fields still work', () {
      final r = run(min: 10, max: 60, optMin: 20, optMax: 35);
      expect(r.flowStatus(5), FlowStatus.tooLow);
      expect(r.flowStatus(15), FlowStatus.low);
      expect(r.flowStatus(25), FlowStatus.medium);
      expect(r.flowStatus(40), FlowStatus.high);
      expect(r.flowStatus(61), FlowStatus.tooHigh);
    });

    test('every bundled entry has a unit, a number and a gauge', () {
      for (final MapEntry(:key, :value) in bcFlowRanges.entries) {
        final r = FlowRanges.fromMap(value);
        expect(r, isNotNull, reason: key);
        expect(
          value.containsKey('station') || value.containsKey('gauge'),
          isTrue,
          reason: key,
        );
        final anchors = [?r!.low, ?r.medium, ?r.high, ?r.max];
        for (var i = 1; i < anchors.length; i++) {
          expect(anchors[i] > anchors[i - 1], isTrue, reason: key);
        }
      }
    });
  });

  test('numbers read naturally', () {
    expect(FlowRanges.number(25), '25');
    expect(FlowRanges.number(2.1), '2.1');
    expect(FlowRanges.number(1300), '1,300');
    expect(FlowRanges.number(0.25), '0.25');
  });
}
