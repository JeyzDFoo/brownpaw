import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../domain/gauges.dart';
import '../providers/gauges_provider.dart';
import '../providers/realtime_flow_provider.dart';
import '../router.dart';
import '../widgets/favourite_star.dart';
import '../widgets/flow_sparkline.dart';

/// The Gauges tab: your gauges first, then every gauge, with live flow,
/// a week's trend and a search across rivers, stations and runs.
class GaugesScreen extends ConsumerStatefulWidget {
  const GaugesScreen({super.key});

  @override
  ConsumerState<GaugesScreen> createState() => _GaugesScreenState();
}

class _GaugesScreenState extends ConsumerState<GaugesScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allAsync = ref.watch(gaugesProvider);
    final mine = ref.watch(yourGaugesProvider).value ?? const <Gauge>[];

    return allAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Couldn't load gauges"),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => ref.invalidate(gaugesProvider),
                child: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
      data: (all) {
        final items = <Widget>[];
        if (_query.trim().isNotEmpty) {
          final results = all.where((g) => g.matches(_query)).toList();
          items.add(
            _Heading(
              results.isEmpty
                  ? 'No gauges match'
                  : results.length == 1
                  ? '1 gauge'
                  : '${results.length} gauges',
            ),
          );
          items.addAll(results.map((g) => GaugeRow(gauge: g)));
        } else {
          final mineIds = {for (final g in mine) g.id};
          items.add(const _Heading('Your gauges'));
          if (mine.isEmpty) {
            items.add(const _NoGaugesYet());
          } else {
            items.addAll(mine.map((g) => GaugeRow(gauge: g)));
          }
          final rest = all.where((g) => !mineIds.contains(g.id)).toList();
          if (rest.isNotEmpty) {
            items.add(const SizedBox(height: 8));
            items.add(const _Heading('All gauges'));
            items.addAll(rest.map((g) => GaugeRow(gauge: g)));
          }
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: items.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _SearchField(
                  controller: _search,
                  onChanged: (v) => setState(() => _query = v),
                ),
              );
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: items[i - 1],
            );
          },
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: c),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search any river or station',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: ValueListenableBuilder(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear search',
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        filled: true,
        fillColor: theme.colorScheme.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: border(theme.colorScheme.outlineVariant),
        enabledBorder: border(theme.colorScheme.outlineVariant),
        focusedBorder: border(theme.colorScheme.primary),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.6,
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

class _NoGaugesYet extends StatelessWidget {
  const _NoGaugesYet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Star a gauge, or log a run, and it shows up here first.',
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

/// One gauge: river and station, when it last reported, a week's trend
/// and the current flow.
class GaugeRow extends ConsumerWidget {
  const GaugeRow({super.key, required this.gauge});
  final Gauge gauge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final current = ref.watch(realtimeFlowStreamProvider(gauge.stationId));
    final data = current.value;
    final readings = dischargeReadings(data?.readings ?? const []);
    final flow = readings.isEmpty ? null : readings.last.discharge;
    final trend = trendOf(readings);
    final updated = readings.isEmpty
        ? (current.isLoading ? '' : 'No recent reading')
        : updatedAgo(readings.last.timestamp);

    final flowText = flow?.toStringAsFixed(1) ?? '–';
    final label = [
      gauge.title,
      if (gauge.place.isNotEmpty) gauge.place,
      if (flow != null) '$flowText cubic metres per second',
      if (trend != null) trend.label,
      if (updated.isNotEmpty) updated,
    ].join(', ');

    return Material(
      color: theme.colorScheme.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                // A sub-page of Gauges: its URL updates, and the app bar back,
                // system back, iOS swipe and browser back all return here.
                onTap: () => context.go(AppRoutes.gauge(gauge.id)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              gauge.title,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (gauge.place.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(gauge.place, style: muted),
                              ),
                            if (updated.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(updated, style: muted),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      FlowSparkline(
                        points: hourlyWindow(readings, 7),
                        width: 56,
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 60,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              flowText,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('m³/s', style: muted),
                                if (trend != null) ...[
                                  const SizedBox(width: 2),
                                  TrendIcon(
                                    trend,
                                    size: 14,
                                    color: muted?.color,
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: FavouriteStar(
              runIds: [for (final r in gauge.runs) r.riverId],
              what: 'gauge',
              compact: true,
            ),
          ),
        ],
      ),
    );
  }
}

/// An arrow for a gauge trend, drawn as an icon so it renders on every
/// platform without a fallback font.
class TrendIcon extends StatelessWidget {
  const TrendIcon(this.trend, {super.key, this.size = 18, this.color});
  final GaugeTrend trend;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) => Icon(
    switch (trend) {
      GaugeTrend.rising => Icons.arrow_upward,
      GaugeTrend.falling => Icons.arrow_downward,
      GaugeTrend.steady => Icons.arrow_forward,
    },
    size: size,
    color: color,
    semanticLabel: trend.label,
  );
}
