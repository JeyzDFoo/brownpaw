import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../domain/flow_status.dart';
import '../domain/season_stats.dart';
import '../models/descent.dart';
import '../models/river_run.dart';
import '../providers/descents_provider.dart';
import '../providers/river_runs_provider.dart';
import '../widgets/check_in_banner.dart';
import '../router.dart';
import '../theme/app_theme.dart';
import '../widgets/flow_status_chip.dart';
import '../widgets/pebble.dart';
import '../widgets/quick_log_sheet.dart';

/// The home tab: this season at a glance, then every logged run, newest
/// first. Logging itself lives on the centre Log button.
class LogbookScreen extends ConsumerWidget {
  const LogbookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final descentsAsync = ref.watch(allDescentsProvider);
    final runsById = {
      for (final r
          in ref.watch(riverRunsStreamProvider).valueOrNull ?? <RiverRun>[])
        r.riverId: r,
    };

    return descentsAsync.when(
      loading: () => const LoadingPebbles(
        header: true,
        padding: EdgeInsets.fromLTRB(20, 40, 20, 24),
      ),
      error: (e, _) => _Message(
        icon: Icons.cloud_off,
        title: "Couldn't load your logbook",
        body: 'Check your connection and try again.',
        action: FilledButton(
          onPressed: () => ref.invalidate(allDescentsProvider),
          child: const Text('Try again'),
        ),
      ),
      data: (descents) {
        if (descents.isEmpty) {
          return _Message(
            icon: Icons.kayaking,
            title: 'Your logbook is empty',
            body:
                'Log a run and Brownpaw fills in the date, the gauge flow '
                'and your crew for you.',
            action: FilledButton.icon(
              onPressed: () => showQuickLog(context),
              icon: const Icon(Icons.add),
              label: const Text('Log your first run'),
            ),
          );
        }

        final stats = SeasonStats.from(descents);
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            SectionLabel('${stats.year} season'),
            const SizedBox(height: 10),
            const PutInCheckInSlot(),
            _StatsRow(stats: stats),
            const SizedBox(height: 24),
            const SectionLabel('Recent'),
            const SizedBox(height: 10),
            for (final d in descents) ...[
              LogEntryCard(descent: d, run: runsById[d.runId]),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.stats});
  final SeasonStats stats;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Stat(
              highlight: true,
              value: stats.daysOnWater,
              label: stats.daysOnWater == 1
                  ? 'day on the water'
                  : 'days on the water',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Stat(
              value: stats.differentRuns,
              label: stats.differentRuns == 1 ? 'run' : 'different runs',
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _Stat(value: stats.newRuns, label: 'new this season'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.highlight = false,
  });
  final int value;
  final String label;

  /// Drawn as the orange pebble: the season's headline number.
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onFill = highlight ? Riverstone.of(context).card : null;
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: Pebble.decoration(
          context,
          radius: Pebble.alternating(label.length),
          fill: highlight ? Riverstone.of(context).accent : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1.05,
                color: onFill,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: onFill ?? theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One logged run: name and date, then flow with its status and the crew.
class LogEntryCard extends ConsumerWidget {
  const LogEntryCard({super.key, required this.descent, this.run});

  final Descent descent;

  /// The run, when known, so the flow can be judged against its ranges.
  final RiverRun? run;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final flow = descent.flow;
    final crew = descent.crew ?? const <String>[];
    final now = DateTime.now();
    final date = descent.date.year == now.year
        ? DateFormat.MMMd().format(descent.date)
        : DateFormat.yMMMd().format(descent.date);

    return PebbleCard(
      seed: descent.id,
      padding: EdgeInsets.zero,
      child: InkWell(
        // Its own URL, so browser back and links work.
        onTap: () => context.go(AppRoutes.descent(descent.id)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      descent.displayName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(date, style: muted),
                ],
              ),
              if (flow != null || crew.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (flow != null)
                      Text(
                        '${flow.toStringAsFixed(1)} ${descent.flowUnit ?? 'm³/s'}',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    if ((run?.flowStatus(flow) ?? FlowStatus.unknown)
                        case final status when status != FlowStatus.unknown)
                      FlowStatusChip(status: status),
                    if (crew.isNotEmpty)
                      Text('with ${crew.join(', ')}', style: muted),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              body,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            action,
          ],
        ),
      ),
    );
  }
}
