import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../domain/flow_ranges.dart';
import '../domain/flow_status.dart';
import '../domain/gauges.dart';
import '../theme/flow_status_style.dart';

double _x(DateTime t) => t.millisecondsSinceEpoch / 3600000; // hours

LineChartBarData _line(
  List<FlowPoint> points,
  Color color,
  double width, {
  required bool filled,
  Color? fill,
}) => LineChartBarData(
  spots: [for (final p in points) FlSpot(_x(p.time), p.flow)],
  color: color,
  barWidth: width,
  isCurved: false,
  isStrokeCapRound: true,
  isStrokeJoinRound: true,
  dotData: const FlDotData(show: false),
  belowBarData: BarAreaData(
    show: filled,
    color: (fill ?? color).withValues(alpha: 0.18),
  ),
);

/// A y range with max above min whatever the data: flat, negative (gauge
/// noise below zero) or a single point.
({double min, double max}) _yRange(
  List<FlowPoint> points, {
  double pad = 0,
  Iterable<double> include = const [],
}) {
  final values = [...points.map((p) => p.flow), ...include];
  final lo = values.reduce(math.min);
  final hi = values.reduce(math.max);
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
                // Glacier blue: water.
                Theme.of(context).colorScheme.secondary,
                2.2,
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
    this.unit = FlowUnit.cms,
    this.bands,
    this.height = 160,
    this.semanticLabel,
  });

  final List<FlowPoint> points;

  /// What the points measure, for the readout.
  final FlowUnit unit;

  /// A run's low / medium / high flows to shade behind the line, in the
  /// same [unit].
  final FlowRanges? bands;

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
    final y = _yRange(points, pad: 0.1, include: _bandAnchors(points));
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
          rangeAnnotations: RangeAnnotations(
            horizontalRangeAnnotations: _bandFills(context, y.min, y.max),
          ),
          extraLinesData: ExtraLinesData(
            horizontalLines: _bandLines(context, y.min, y.max),
          ),
          lineBarsData: [
            // An ink line over a glacier-blue wash.
            _line(
              points,
              scheme.onSurface,
              3,
              // With bands behind it, the wash would hide them.
              filled: bands == null,
              fill: scheme.secondary,
            ),
          ],
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
                  FlLine(color: scheme.secondary.withValues(alpha: 0.5)),
                  FlDotData(
                    getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                      radius: 4,
                      color: scheme.secondary,
                      strokeWidth: 2,
                      strokeColor: scheme.surfaceContainerLow,
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
                    '${_readout(s.y)} ${unit.symbol}\n',
                    TextStyle(
                      color: scheme.onInverseSurface,
                      fontWeight: FontWeight.w800,
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

  String _readout(double v) =>
      unit == FlowUnit.metres ? v.toStringAsFixed(2) : v.toStringAsFixed(1);

  /// Band edges worth keeping on screen: low and medium always (so a
  /// trickle still shows how far it is from runnable), high when it isn't
  /// far above everything else.
  List<double> _bandAnchors(List<FlowPoint> points) {
    final b = bands;
    if (b == null) return const [];
    final top = points.map((p) => p.flow).reduce(math.max);
    final near = [?b.low, ?b.medium];
    final reach = math.max(top, near.fold<double>(0, math.max)) * 2.5;
    return [
      ...near,
      if (b.high != null && b.high! <= reach) b.high!,
      if (b.max != null && b.max! <= reach) b.max!,
    ];
  }

  /// The bands from low up, each with the status it stands for.
  List<({double from, double to, FlowStatus status})> _bandSpans(
    double minY,
    double maxY,
  ) {
    final b = bands;
    if (b == null) return const [];
    final edges = <({double at, FlowStatus status})>[
      if (b.low != null) (at: b.low!, status: FlowStatus.low),
      if (b.medium != null) (at: b.medium!, status: FlowStatus.medium),
      if (b.high != null) (at: b.high!, status: FlowStatus.high),
      if (b.max != null) (at: b.max!, status: FlowStatus.tooHigh),
    ];
    if (edges.isEmpty) return const [];
    return [
      if (b.low != null) (from: minY, to: b.low!, status: FlowStatus.tooLow),
      for (var i = 0; i < edges.length; i++)
        (
          from: edges[i].at,
          to: i + 1 < edges.length ? edges[i + 1].at : maxY,
          status: edges[i].status,
        ),
    ];
  }

  List<HorizontalRangeAnnotation> _bandFills(
    BuildContext context,
    double minY,
    double maxY,
  ) => [
    for (final s in _bandSpans(minY, maxY))
      if (s.to > minY && s.from < maxY)
        HorizontalRangeAnnotation(
          y1: math.max(s.from, minY),
          y2: math.min(s.to, maxY),
          color: s.status
              .color(context)
              .withValues(alpha: s.status == FlowStatus.medium ? 0.16 : 0.09),
        ),
  ];

  List<HorizontalLine> _bandLines(
    BuildContext context,
    double minY,
    double maxY,
  ) {
    final b = bands;
    if (b == null) return const [];
    final style = Theme.of(context).textTheme.labelSmall;
    HorizontalLine line(double at, String word, FlowStatus status) {
      final color = status.color(context);
      return HorizontalLine(
        y: at,
        color: color.withValues(alpha: 0.7),
        strokeWidth: 1,
        dashArray: const [3, 3],
        label: HorizontalLineLabel(
          show: true,
          alignment: Alignment.topLeft,
          padding: const EdgeInsets.only(left: 4, bottom: 1),
          style: style?.copyWith(color: color, fontWeight: FontWeight.w800),
          labelResolver: (_) => word,
        ),
      );
    }

    return [
      if (b.low != null) line(b.low!, 'Low', FlowStatus.low),
      if (b.medium != null) line(b.medium!, 'Medium', FlowStatus.medium),
      if (b.high != null) line(b.high!, 'High', FlowStatus.high),
      if (b.max != null) line(b.max!, 'Too high', FlowStatus.tooHigh),
    ].where((l) => l.y > minY && l.y < maxY).toList();
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
