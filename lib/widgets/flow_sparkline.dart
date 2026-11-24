import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/gauges.dart';

double _x(DateTime t) => t.millisecondsSinceEpoch / 3600000; // hours

LineChartBarData _line(
  List<FlowPoint> points,
  Color color,
  double width, {
  required bool filled,
}) => LineChartBarData(
  spots: [for (final p in points) FlSpot(_x(p.time), p.flow)],
  color: color,
  barWidth: width,
  isCurved: false,
  isStrokeCapRound: true,
  isStrokeJoinRound: true,
  dotData: const FlDotData(show: false),
  belowBarData: BarAreaData(show: filled, color: color.withValues(alpha: 0.12)),
);

/// A y range with max above min whatever the data: flat, negative (gauge
/// noise below zero) or a single point.
({double min, double max}) _yRange(List<FlowPoint> points, {double pad = 0}) {
  final lo = points.map((p) => p.flow).reduce(math.min);
  final hi = points.map((p) => p.flow).reduce(math.max);
  final span = hi - lo == 0 ? math.max(hi.abs() * 0.1, 1.0) : hi - lo;
  final p = hi == lo ? math.max(pad, 0.5) : pad;
  final min = lo >= 0 ? math.max(0.0, lo - span * p) : lo - span * p;
  return (min: min, max: math.max(hi + span * p, min + span));
}

/// Points safe to chart: finite flows, oldest first, no repeated times.
List<FlowPoint> _chartable(List<FlowPoint> points) {
  final out = [
    for (final p in points)
      if (p.flow.isFinite) p,
  ]..sort((a, b) => a.time.compareTo(b.time));
  return out;
}

/// A small line of recent flow for a gauge tile. Not interactive.
class FlowSparkline extends StatelessWidget {
  const FlowSparkline({
    super.key,
    required this.points,
    this.width = 76,
    this.height = 32,
  });

  final List<FlowPoint> points;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    final points = _chartable(this.points);
    if (points.length < 2 || !points.last.time.isAfter(points.first.time)) {
      return SizedBox(width: width, height: height);
    }
    final y = _yRange(points, pad: 0.08);
    return ExcludeSemantics(
      child: SizedBox(
        width: width,
        height: height,
        child: LineChart(
          LineChartData(
            minY: y.min,
            maxY: y.max,
            lineBarsData: [
              _line(
                points,
                Theme.of(context).colorScheme.primary,
                2,
                filled: false,
              ),
            ],
            titlesData: const FlTitlesData(show: false),
            gridData: const FlGridData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            clipData: const FlClipData.all(),
          ),
          duration: Duration.zero,
        ),
      ),
    );
  }
}

/// The gauge page chart: flow over time, filled to the baseline, with
/// light guide lines and a touch readout of flow and time.
class GaugeFlowChart extends StatelessWidget {
  const GaugeFlowChart({
    super.key,
    required this.points,
    required this.daily,
    this.height = 160,
    this.semanticLabel,
  });

  final List<FlowPoint> points;

  /// Daily means rather than hourly readings, for the readout's format.
  final bool daily;
  final double height;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final points = _chartable(this.points);
    if (points.length < 2 || !points.last.time.isAfter(points.first.time)) {
      return SizedBox(height: height);
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final y = _yRange(points, pad: 0.1);
    final interval = _niceInterval((y.max - y.min) / 3);
    final timeFormat = daily ? DateFormat.MMMd() : DateFormat('MMM d, h a');
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );

    final chart = SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: y.min,
          maxY: y.max,
          minX: _x(points.first.time),
          maxX: _x(points.last.time),
          lineBarsData: [_line(points, scheme.primary, 2.5, filled: true)],
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: interval,
            getDrawingHorizontalLine: (_) => FlLine(
              color: scheme.outlineVariant.withValues(alpha: 0.6),
              strokeWidth: 1,
              dashArray: const [4, 4],
            ),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            bottomTitles: const AxisTitles(),
            leftTitles: const AxisTitles(),
            rightTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: interval,
                getTitlesWidget: (value, meta) {
                  if (value == meta.min || value == meta.max) {
                    return const SizedBox.shrink();
                  }
                  return SideTitleWidget(
                    meta: meta,
                    child: Text(_fmt(value), style: labelStyle),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            handleBuiltInTouches: true,
            getTouchedSpotIndicator: (bar, indexes) => [
              for (final _ in indexes)
                TouchedSpotIndicatorData(
                  FlLine(color: scheme.primary.withValues(alpha: 0.5)),
                  FlDotData(
                    getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                      radius: 4,
                      color: scheme.primary,
                      strokeWidth: 2,
                      strokeColor: scheme.surface,
                    ),
                  ),
                ),
            ],
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => scheme.inverseSurface,
              tooltipBorderRadius: BorderRadius.circular(8),
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItems: (spots) => [
                for (final s in spots)
                  LineTooltipItem(
                    '${s.y.toStringAsFixed(1)} m³/s\n',
                    TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w700,
                    ),
                    children: [
                      TextSpan(
                        text: timeFormat.format(
                          DateTime.fromMillisecondsSinceEpoch(
                            (s.x * 3600000).round(),
                          ).toLocal(),
                        ),
                        style: TextStyle(
                          color: scheme.onInverseSurface,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        duration: const Duration(milliseconds: 250),
      ),
    );
    if (semanticLabel == null) return chart;
    return Semantics(label: semanticLabel, image: true, child: chart);
  }

  static double _niceInterval(double raw) {
    if (raw <= 0) return 1;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    for (final step in [1, 2, 2.5, 5, 10]) {
      if (raw <= step * mag) return step * mag;
    }
    return 10 * mag;
  }

  static String _fmt(double v) => v >= 10 || v == v.roundToDouble()
      ? v.round().toString()
      : v.toStringAsFixed(1);
}
