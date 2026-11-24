import '../models/river_run.dart';

/// How a run's current flow compares with its known flow ranges.
///
/// This is the single source of truth for "is it in?". Screens should use
/// [FlowStatus.evaluate] (or [RiverRunFlowStatus.flowStatus]) rather than
/// comparing flows themselves, so a run never shows two different answers.
enum FlowStatus {
  /// No flow reading, or the run has no flow ranges to compare against.
  unknown,

  /// Below the lowest recommended (or optimal) flow.
  tooLow,

  /// Inside the recommended range but outside the optimal range.
  runnable,

  /// Inside the optimal range.
  good,

  /// Above the highest recommended (or optimal) flow.
  tooHigh;

  /// Short label shown next to the status colour and icon.
  String get label => switch (this) {
    FlowStatus.unknown => 'No range',
    FlowStatus.tooLow => 'Low',
    FlowStatus.runnable => 'Runnable',
    FlowStatus.good => 'Good',
    FlowStatus.tooHigh => 'High',
  };

  /// Whether the run is generally considered paddleable at this flow.
  bool get isRunnable => this == FlowStatus.runnable || this == FlowStatus.good;

  /// Compares [flow] with the given ranges. Any bound may be missing.
  ///
  /// Rules, in order:
  /// 1. No flow, or no bounds at all: [unknown].
  /// 2. Inside the optimal range (both optimal bounds known): [good].
  /// 3. Below the lowest known lower bound: [tooLow].
  /// 4. Above the highest known upper bound: [tooHigh].
  /// 5. Otherwise, inside the known bounds: [runnable].
  static FlowStatus evaluate({
    required double? flow,
    double? minRecommended,
    double? maxRecommended,
    double? optimalMin,
    double? optimalMax,
  }) {
    if (flow == null || flow.isNaN) return FlowStatus.unknown;

    final lowerBounds = [minRecommended, optimalMin].whereType<double>();
    final upperBounds = [maxRecommended, optimalMax].whereType<double>();
    if (lowerBounds.isEmpty && upperBounds.isEmpty) return FlowStatus.unknown;

    if (optimalMin != null &&
        optimalMax != null &&
        flow >= optimalMin &&
        flow <= optimalMax) {
      return FlowStatus.good;
    }

    if (lowerBounds.isNotEmpty &&
        flow < lowerBounds.reduce((a, b) => a < b ? a : b)) {
      return FlowStatus.tooLow;
    }
    if (upperBounds.isNotEmpty &&
        flow > upperBounds.reduce((a, b) => a > b ? a : b)) {
      return FlowStatus.tooHigh;
    }
    return FlowStatus.runnable;
  }
}

extension RiverRunFlowStatus on RiverRun {
  /// Whether this run has any flow range to judge a reading against.
  bool get hasFlowRanges =>
      minRecommendedFlow != null ||
      maxRecommendedFlow != null ||
      optimalFlowMin != null ||
      optimalFlowMax != null;

  /// The status of this run at [flow].
  FlowStatus flowStatus(double? flow) => FlowStatus.evaluate(
    flow: flow,
    minRecommended: minRecommendedFlow,
    maxRecommended: maxRecommendedFlow,
    optimalMin: optimalFlowMin,
    optimalMax: optimalFlowMax,
  );
}
