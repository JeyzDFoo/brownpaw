import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/flow_alert.dart';
import '../domain/flow_ranges.dart';
import '../domain/flow_status.dart';
import '../domain/gauges.dart';
import '../models/realtime_flow.dart';
import '../models/river_run.dart';
import '../providers/gauges_provider.dart';
import '../providers/realtime_flow_provider.dart';
import '../router.dart';
import '../widgets/alert_bell.dart';
import '../widgets/favourite_star.dart';
import '../widgets/flow_sparkline.dart';
import '../widgets/flow_status_chip.dart';
import 'gauges_screen.dart' show TrendIcon;
import '../theme/app_theme.dart';
import '../widgets/pebble.dart';

/// One gauge: the flow now, how it has moved, and how each run on it is.
class GaugeScreen extends ConsumerWidget {
  const GaugeScreen({super.key, required this.gaugeId});
  final String gaugeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final gaugeAsync = ref.watch(gaugeProvider(gaugeId));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (gaugeAsync.valueOrNull case final gauge?)
            FavouriteStar(
              runIds: [for (final r in gauge.runs) r.riverId],
              what: 'gauge',
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: gaugeAsync.when(
        loading: () => const LoadingPebbles(count: 3, height: 140),
        error: (e, _) => const Center(child: Text("Couldn't load this gauge")),
        data: (gauge) => gauge == null
            ? const Center(child: Text('No runs use this gauge'))
            : _GaugeBody(gauge: gauge),
      ),
    );
  }
}

class _GaugeBody extends ConsumerWidget {
  const _GaugeBody({required this.gauge});
  final Gauge gauge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final current = ref.watch(realtimeFlowStreamProvider(gauge.stationId));
    final all = current.valueOrNull?.readings ?? const <FlowReading>[];
    // Lead with what the runs here are judged in: metres on the stick for
    // the Cheakamus and Chilliwack, else m³/s.
    var unit = gaugeUnit(gauge.runs);
    if (unit == FlowUnit.metres && readingsIn(all, unit).isEmpty) {
      unit = FlowUnit.cms;
    }
    final readings = readingsIn(all, unit);
    final value = readings.isEmpty ? null : valueIn(readings.last, unit);
    final latest = all.isEmpty ? null : all.last;
    final flow = latest?.discharge;
    final level = latest?.level;
    final other = unit == FlowUnit.metres && flow != null
        ? '${flow.toStringAsFixed(1)} m³/s'
        : null;
    final trend = trendOf(dischargeReadings(all));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text(
          gauge.title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        if (gauge.place.isNotEmpty) Text(gauge.place, style: muted),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: Pebble.a,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    value == null
                        ? '–'
                        : value.toStringAsFixed(
                            unit == FlowUnit.metres ? 2 : 1,
                          ),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    unit.symbol,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: trend == null
                        ? const SizedBox.shrink()
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TrendIcon(trend, size: 18),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  trend.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                [
                  readings.isEmpty
                      ? (current.isLoading ? '' : 'No recent reading')
                      : updatedAgo(readings.last.timestamp),
                  ?other,
                  gaugeSource(gauge.id),
                ].where((s) => s.isNotEmpty).join(' · '),
                style: muted,
              ),
              if (readings.isNotEmpty && isStale(readings.last.timestamp))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    "This gauge hasn't reported for a while, so the river may "
                    'have changed. Check before you go.',
                    style: muted?.copyWith(color: Riverstone.of(context).low),
                  ),
                ),
              const SizedBox(height: 12),
              _FlowChart(gauge: gauge, readings: all, unit: unit),
            ],
          ),
        ),
        const SizedBox(height: 22),
        SectionLabel(
          gauge.runs.length == 1 ? 'Run on this gauge' : 'Runs on this gauge',
        ),
        const SizedBox(height: 10),
        for (final run in gauge.runs) ...[
          _RunOnGauge(run: run, flow: flow, level: level),
          const SizedBox(height: 10),
        ],
        if (gauge.runs.any((r) => alertRangeFor(r) != null))
          Row(
            children: [
              Icon(
                Icons.notifications_none,
                size: 16,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Tap the bell to get a notification when a run comes '
                  'into range.',
                  style: muted,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The flow chart with its timeframe picker. Hourly readings back the
/// short spans; daily means back six months and a year.
class _FlowChart extends ConsumerStatefulWidget {
  const _FlowChart({
    required this.gauge,
    required this.readings,
    required this.unit,
  });
  final Gauge gauge;
  final List<FlowReading> readings;
  final FlowUnit unit;

  @override
  ConsumerState<_FlowChart> createState() => _FlowChartState();
}

class _FlowChartState extends ConsumerState<_FlowChart> {
  GaugeSpan _span = GaugeSpan.twoWeeks;
  String? _bandRunId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final unit = widget.unit;
    // Runs whose low / medium / high can be drawn on this chart.
    final banded = [
      for (final run in widget.gauge.runs)
        if (run.ranges case final r?
            when r.readOnGaugeOf(run) && r.unit == unit)
          run,
    ];
    final bandRun =
        banded.where((r) => r.riverId == _bandRunId).firstOrNull ??
        banded.firstOrNull;

    List<FlowPoint> points;
    var loading = false;
    if (_span.usesDaily) {
      final daily = ref.watch(
        gaugeDailyFlowsProvider((
          stationId: widget.gauge.stationId,
          days: _span.days,
          unit: unit,
        )),
      );
      loading = daily.isLoading;
      points = [...daily.valueOrNull ?? const <FlowPoint>[]];
      // End on the live reading so the chart meets the number above it.
      final live = hourlyWindow(widget.readings, 2, unit: unit);
      if (live.isNotEmpty &&
          (points.isEmpty || live.last.time.isAfter(points.last.time))) {
        points.add(live.last);
      }
    } else {
      points = hourlyWindow(widget.readings, _span.days, unit: unit);
    }
    final values = [for (final p in points) p.flow];

    final unitWords = unit == FlowUnit.metres
        ? 'metres on the gauge'
        : 'cubic metres per second';
    final bands = bandRun?.ranges;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (banded.length > 1) ...[
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final run in banded) ...[
                  ChoiceChip(
                    label: Text(runLabel(run)),
                    selected: run == bandRun,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _bandRunId = run.riverId),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
        SizedBox(
          height: 180,
          child: values.length >= 2
              ? GaugeFlowChart(
                  points: points,
                  daily: _span.usesDaily,
                  unit: unit,
                  bands: bands,
                  height: 180,
                  semanticLabel:
                      'Flow over the last ${_span.label}, from '
                      '${values.first.toStringAsFixed(1)} to '
                      '${values.last.toStringAsFixed(1)} $unitWords'
                      '${bands == null ? '' : '. ${bands.summary}'}',
                )
              : Center(
                  child: loading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        )
                      : Text('No readings for this span', style: muted),
                ),
        ),
        const SizedBox(height: 4),
        ExcludeSemantics(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${_span.label} ago', style: muted),
              Text('Now', style: muted),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<GaugeSpan>(
          showSelectedIcon: false,
          style: SegmentedButton.styleFrom(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.padded,
          ),
          segments: [
            for (final span in GaugeSpan.values)
              ButtonSegment(
                value: span,
                label: Text(span.short),
                tooltip: span.label,
              ),
          ],
          selected: {_span},
          onSelectionChanged: (s) => setState(() => _span = s.first),
        ),
      ],
    );
  }
}

class _RunOnGauge extends ConsumerWidget {
  const _RunOnGauge({required this.run, required this.flow, this.level});
  final RiverRun run;
  final double? flow;
  final double? level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final grade = run.difficultyText;
    final range = rangeSummary(run);
    final status = run.flowStatus(flow, level: level);
    final detail = [
      if (grade.isNotEmpty) grade.startsWith('Class') ? grade : 'Class $grade',
      ?range,
    ].join(' · ');

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: Pebble.small),
      child: InkWell(
        borderRadius: Pebble.small,
        onTap: () => context.push(AppRoutes.run(run.riverId)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      runLabel(run),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (detail.isNotEmpty)
                      Text(
                        detail,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (status != FlowStatus.unknown) ...[
                const SizedBox(width: 8),
                FlowStatusChip(status: status),
              ],
              if (alertRangeFor(run) != null) AlertBell(run: run),
            ],
          ),
        ),
      ),
    );
  }
}
