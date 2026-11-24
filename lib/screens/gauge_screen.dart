import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/flow_status.dart';
import '../domain/gauges.dart';
import '../models/river_run.dart';
import '../providers/gauges_provider.dart';
import '../providers/realtime_flow_provider.dart';
import '../router.dart';
import '../widgets/flow_sparkline.dart';
import '../widgets/flow_status_chip.dart';
import 'gauges_screen.dart' show TrendIcon;

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
      ),
      body: gaugeAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
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
    final readings = dischargeReadings(current.value?.readings ?? const []);
    final flow = readings.isEmpty ? null : readings.last.discharge;
    final trend = trendOf(readings);
    final days = readings.length < 2
        ? 0
        : readings.last.timestamp.difference(readings.first.timestamp).inDays;
    final values = [for (final r in readings) r.discharge!];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text(
          gauge.river,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (gauge.place.isNotEmpty) Text(gauge.place, style: muted),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    flow?.toStringAsFixed(1) ?? '–',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'm³/s',
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
                                    fontWeight: FontWeight.w600,
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
                readings.isEmpty
                    ? (current.isLoading ? '' : 'No recent reading')
                    : updatedAgo(readings.last.timestamp),
                style: muted,
              ),
              if (values.length >= 2) ...[
                const SizedBox(height: 12),
                LayoutBuilder(
                  builder: (context, c) => FlowSparkline(
                    values: values,
                    width: c.maxWidth,
                    height: 130,
                    filled: true,
                    semanticLabel:
                        'Flow over the last ${_span(days)}, from '
                        '${values.first.toStringAsFixed(1)} to '
                        '${values.last.toStringAsFixed(1)} cubic metres '
                        'per second',
                  ),
                ),
                const SizedBox(height: 4),
                ExcludeSemantics(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_span(days)} ago', style: muted),
                      Text('Now', style: muted),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        Semantics(
          header: true,
          child: Text(
            gauge.runs.length == 1 ? 'RUN ON THIS GAUGE' : 'RUNS ON THIS GAUGE',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 10),
        for (final run in gauge.runs) ...[
          _RunOnGauge(run: run, flow: flow),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  static String _span(int days) => days <= 1 ? '24 hours' : '$days days';
}

class _RunOnGauge extends StatelessWidget {
  const _RunOnGauge({required this.run, required this.flow});
  final RiverRun run;
  final double? flow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final grade = run.difficultyText;
    final range = goodRange(run);
    final detail = [
      if (grade.isNotEmpty) grade.startsWith('Class') ? grade : 'Class $grade',
      ?range,
    ].join(' · ');

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
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
                      run.name,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
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
              if (flow != null && run.hasFlowRanges) ...[
                const SizedBox(width: 8),
                FlowStatusChip(status: run.flowStatus(flow)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
