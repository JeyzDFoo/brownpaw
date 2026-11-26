import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/gauge_repository.dart' show StationSummary;
import '../domain/flow_status.dart';
import '../domain/gauges.dart';
import '../providers/gauges_provider.dart';
import '../providers/realtime_flow_provider.dart';
import '../router.dart';
import '../widgets/check_in_banner.dart';
import '../widgets/favourite_star.dart';
import '../widgets/flow_sparkline.dart';
import '../widgets/flow_status_chip.dart';
import '../theme/app_theme.dart';
import '../widgets/pebble.dart';

/// The Gauges tab: starred gauges, then ones you've logged, then the rest,
/// each with what's running first, then what's nearest. Live flow, a week's
/// trend and a search across rivers, stations and runs.
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
    final sectionsAsync = ref.watch(gaugeSectionsProvider);

    return sectionsAsync.when(
      loading: () => const LoadingPebbles(
        count: 5,
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
      ),
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
      data: (sections) {
        final items = <Widget>[];
        if (_query.trim().isNotEmpty) {
          final results = sortGauges(
            [
              ...sections.starred,
              ...sections.recent,
              ...sections.all,
            ].where((g) => g.matches(_query)).toList(),
            stations: ref.watch(stationsProvider).valueOrNull ?? const {},
            position: ref.watch(devicePositionProvider).valueOrNull,
          );
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
          items.add(const _Heading('Starred'));
          if (sections.starred.isEmpty) {
            items.add(const _NoGaugesYet());
          } else {
            items.addAll(sections.starred.map((g) => GaugeRow(gauge: g)));
          }
          for (final (title, list) in [
            ('Recent', sections.recent),
            ('All', sections.all),
          ]) {
            if (list.isEmpty) continue;
            items.add(const SizedBox(height: 8));
            items.add(_Heading(title));
            items.addAll(list.map((g) => GaugeRow(gauge: g)));
          }
        }

        return ListView.builder(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          itemCount: items.length + 1,
          itemBuilder: (context, i) {
            if (i == 0) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const PutInCheckInSlot(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _SearchField(
                      controller: _search,
                      onChanged: (v) => setState(() => _query = v),
                    ),
                  ),
                ],
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
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
        fillColor: theme.colorScheme.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

class _Heading extends StatelessWidget {
  const _Heading(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => SectionLabel(text);
}

class _NoGaugesYet extends StatelessWidget {
  const _NoGaugesYet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      'Tap the star on any gauge to keep it up here.',
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
    final data = current.valueOrNull;
    final readings = dischargeReadings(data?.readings ?? const []);
    final flow = readings.isEmpty ? null : readings.last.discharge;
    final trend = trendOf(readings);
    final updated = readings.isEmpty
        ? (current.isLoading ? '' : 'No recent reading')
        : updatedAgo(readings.last.timestamp);
    // The same judgement the list is sorted on.
    final status = data == null
        ? FlowStatus.unknown
        : gaugeStatus(gauge, StationSummary.fromLive(data));
    final position = ref.watch(devicePositionProvider).valueOrNull;
    final km = position == null ? null : gaugeDistanceKm(gauge, position);
    final away = km == null ? null : distanceLabel(km);

    final flowText = flow?.toStringAsFixed(1) ?? '–';
    final label = [
      gauge.title,
      if (gauge.place.isNotEmpty) gauge.place,
      if (flow != null) '$flowText cubic metres per second',
      if (trend != null) trend.label,
      if (status != FlowStatus.unknown) status.label,
      if (updated.isNotEmpty) updated,
      ?away,
    ].join(', ');

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: Pebble.a),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: Pebble.a,
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
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (gauge.place.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(gauge.place, style: muted),
                              ),
                            if (updated.isNotEmpty || away != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: updated,
                                        // Old readings stand out in ochre.
                                        style:
                                            readings.isNotEmpty &&
                                                isStale(readings.last.timestamp)
                                            ? TextStyle(
                                                color: Riverstone.of(
                                                  context,
                                                ).low,
                                              )
                                            : null,
                                      ),
                                      if (away != null)
                                        TextSpan(
                                          text: updated.isEmpty
                                              ? away
                                              : ' · $away',
                                        ),
                                    ],
                                  ),
                                  style: muted,
                                ),
                              ),
                            if (status != FlowStatus.unknown)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: FlowStatusChip(status: status),
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
                        width: 64,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                flowText,
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
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
