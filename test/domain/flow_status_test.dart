import 'package:brownpaw/domain/flow_status.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  FlowStatus eval(
    double? flow, {
    double? min,
    double? max,
    double? optMin,
    double? optMax,
  }) => FlowStatus.evaluate(
    flow: flow,
    minRecommended: min,
    maxRecommended: max,
    optimalMin: optMin,
    optimalMax: optMax,
  );

  group('FlowStatus.evaluate', () {
    test('unknown without a reading', () {
      expect(eval(null, min: 10, max: 50), FlowStatus.unknown);
      expect(eval(double.nan, min: 10, max: 50), FlowStatus.unknown);
    });

    test('unknown without any ranges', () {
      expect(eval(20), FlowStatus.unknown);
    });

    group('with recommended and optimal ranges', () {
      FlowStatus full(double f) =>
          eval(f, min: 10, max: 50, optMin: 20, optMax: 35);

      test('good inside optimal, inclusive', () {
        expect(full(20), FlowStatus.good);
        expect(full(27), FlowStatus.good);
        expect(full(35), FlowStatus.good);
      });

      test('runnable inside recommended but outside optimal', () {
        expect(full(10), FlowStatus.runnable);
        expect(full(15), FlowStatus.runnable);
        expect(full(50), FlowStatus.runnable);
      });

      test('low and high outside recommended', () {
        expect(full(9.9), FlowStatus.tooLow);
        expect(full(50.1), FlowStatus.tooHigh);
      });
    });

    test('recommended range only', () {
      expect(eval(5, min: 10, max: 50), FlowStatus.tooLow);
      expect(eval(30, min: 10, max: 50), FlowStatus.runnable);
      expect(eval(60, min: 10, max: 50), FlowStatus.tooHigh);
    });

    test('optimal range only: below is low, not high', () {
      // The old run page reported "High" here.
      expect(eval(5, optMin: 20, optMax: 35), FlowStatus.tooLow);
      expect(eval(25, optMin: 20, optMax: 35), FlowStatus.good);
      expect(eval(40, optMin: 20, optMax: 35), FlowStatus.tooHigh);
    });

    test('a single bound still gives an answer', () {
      expect(eval(5, min: 10), FlowStatus.tooLow);
      expect(eval(15, min: 10), FlowStatus.runnable);
      expect(eval(60, max: 50), FlowStatus.tooHigh);
      expect(eval(40, max: 50), FlowStatus.runnable);
    });
  });

  test('labels use plain words', () {
    expect(FlowStatus.tooLow.label, 'Low');
    expect(FlowStatus.good.label, 'Good');
    expect(FlowStatus.tooHigh.label, 'High');
    expect(FlowStatus.good.isRunnable, isTrue);
    expect(FlowStatus.tooHigh.isRunnable, isFalse);
  });
}
