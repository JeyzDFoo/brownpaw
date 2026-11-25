import '../models/river_run.dart';
import 'flow_ranges.dart';

/// Where a reading sits in a run's low / medium / high flows.
///
/// This is the single source of truth for "is it in?". Screens should use
/// [RiverRunFlowStatus.flowStatus] rather than comparing flows themselves,
/// so a run never shows two different answers.
enum FlowStatus {
  /// No reading, or no flows to compare it with.
  unknown,

  /// Below the low flow.
  tooLow,

  /// From low up to medium.
  low,

  /// Above the low flow when the source gives no medium.
  runnable,

  /// From medium up to high.
  medium,

  /// From high up to the maximum, if there is one.
  high,

  /// Above the maximum.
  tooHigh;

  /// Short label shown next to the status colour and icon.
  String get label => switch (this) {
    FlowStatus.unknown => 'No range',
    FlowStatus.tooLow => 'Too low',
    FlowStatus.low => 'Low',
    FlowStatus.runnable => 'Runnable',
    FlowStatus.medium => 'Medium',
    FlowStatus.high => 'High',
    FlowStatus.tooHigh => 'Too high',
  };

  /// Whether the run is generally considered paddleable at this flow.
  bool get isRunnable =>
      this == FlowStatus.low ||
      this == FlowStatus.runnable ||
      this == FlowStatus.medium ||
      this == FlowStatus.high;

  /// Where [value] sits in [ranges]. Each number is where its level
  /// starts; any may be missing.
  static FlowStatus evaluate(FlowRanges? ranges, double? value) {
    if (ranges == null || ranges.isEmpty) return FlowStatus.unknown;
    if (value == null || !value.isFinite) return FlowStatus.unknown;
    final FlowRanges(:low, :medium, :high, :max) = ranges;

    if (low != null && value < low) return FlowStatus.tooLow;
    if (max != null && value > max) return FlowStatus.tooHigh;
    if (high != null && value >= high) return FlowStatus.high;
    if (medium != null && value >= medium) return FlowStatus.medium;
    // Below medium (or high), and not too low.
    if (medium != null) return FlowStatus.low;
    if (low != null) return FlowStatus.runnable;
    // Only an upper bound: under the maximum is fine, but under "high"
    // alone says nothing about whether there's enough water.
    if (max != null && high == null) return FlowStatus.runnable;
    return FlowStatus.unknown;
  }
}

extension RiverRunFlowStatus on RiverRun {
  /// Whether this run's flows can be compared with its own gauge's
  /// readings (rather than shown as a reference only).
  bool get hasFlowRanges => ranges?.readOnGaugeOf(this) ?? false;

  /// The status of this run with its gauge at [flow] (discharge) and
  /// [level] (water level). Runs measured in metres need [level].
  FlowStatus flowStatus(double? flow, {double? level}) {
    final r = ranges;
    if (r == null || !r.readOnGaugeOf(this)) return FlowStatus.unknown;
    return FlowStatus.evaluate(r, r.unit == FlowUnit.metres ? level : flow);
  }
}
