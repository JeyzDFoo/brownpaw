import '../models/river_run.dart';
import 'flow_ranges.dart';

/// The flow range an alert watches for, and how to describe it.
class AlertRange {
  const AlertRange(this.min, this.max, this.word);
  final double min;
  final double max;

  /// "good" for the optimal range, "runnable" for the recommended one.
  final String word;

  String get text => '${_n(min)} to ${_n(max)} m³/s';

  static String _n(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
}

/// The range to alert on: the good range when the run has one, else the
/// runnable range. Null when the run has neither, or its flows are read in
/// metres or on another gauge (alerts compare discharge on the run's own
/// gauge).
AlertRange? alertRangeFor(RiverRun run) {
  final r = run.ranges;
  if (r != null &&
      r.unit == FlowUnit.cms &&
      r.readOnGaugeOf(run) &&
      run.optimalFlowMin == null &&
      run.minRecommendedFlow == null) {
    if (r.medium != null && r.high != null) {
      return AlertRange(r.medium!, r.high!, 'medium');
    }
    final top = r.high ?? r.max;
    if (r.low != null && top != null) {
      return AlertRange(r.low!, top, 'runnable');
    }
    return null;
  }
  if (run.optimalFlowMin != null && run.optimalFlowMax != null) {
    return AlertRange(run.optimalFlowMin!, run.optimalFlowMax!, 'good');
  }
  if (run.minRecommendedFlow != null && run.maxRecommendedFlow != null) {
    return AlertRange(
      run.minRecommendedFlow!,
      run.maxRecommendedFlow!,
      'runnable',
    );
  }
  return null;
}
