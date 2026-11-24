import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/location_service.dart';
import '../domain/flow_status.dart';
import '../domain/season_stats.dart';
import '../models/descent.dart';
import '../models/river_run.dart';
import '../providers/check_in_provider.dart';
import '../providers/descents_provider.dart';
import '../providers/river_runs_provider.dart';
import '../widgets/check_in_banner.dart';
import '../widgets/descent_details_sheet.dart';
import '../widgets/flow_status_chip.dart';
import '../widgets/quick_log_sheet.dart';

/// The home tab: this season at a glance, then every logged run, newest
/// first. Logging itself lives on the centre Log button.
class LogbookScreen extends ConsumerWidget {
  const LogbookScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final descentsAsync = ref.watch(allDescentsProvider);
    final runsById = {
      for (final r in ref.watch(riverRunsStreamProvider).value ?? <RiverRun>[])
        r.riverId: r,
    };

    return descentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
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
            Text(
              '${stats.year} season',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            _CheckInSlot(descents: descents),
            _StatsRow(stats: stats),
            const SizedBox(height: 24),
            Text(
              'RECENT',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
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

/// The put-in check-in, or the one-time card that asks for location.
class _CheckInSlot extends ConsumerWidget {
  const _CheckInSlot({required this.descents});
  final List<Descent> descents;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checkIn = ref.watch(putInCheckInProvider).value;
    final dismissed = ref.watch(dismissedCheckInsProvider);
    Widget? card;

    if (checkIn != null && !dismissed.contains(checkIn.run.riverId)) {
      final now = DateTime.now();
      final loggedToday = descents.any(
        (d) =>
            d.runId == checkIn.run.riverId &&
            d.date.year == now.year &&
            d.date.month == now.month &&
            d.date.day == now.day,
      );
      if (!loggedToday) card = CheckInBanner(checkIn: checkIn);
    } else if (ref.watch(locationAccessProvider).value ==
            LocationAccess.askable &&
        ref.watch(locationPromptDismissedProvider).value == false) {
      card = const LocationPromptCard();
    }

    if (card == null) return const SizedBox.shrink();
    return Padding(padding: const EdgeInsets.only(bottom: 16), child: card);
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
  const _Stat({required this.value, required this.label});
  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '$value $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$value',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
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

    return Material(
      color: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => Scaffold(
              body: DescentDetailsSheet(
                descent: descent,
                scrollController: ScrollController(),
                ref: ref,
              ),
            ),
          ),
        ),
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
                        fontWeight: FontWeight.w700,
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
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    if (flow != null && (run?.hasFlowRanges ?? false))
                      FlowStatusChip(status: run!.flowStatus(flow)),
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
                fontWeight: FontWeight.w700,
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
