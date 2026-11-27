import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/dam_release.dart';
import '../domain/flow_status.dart';
import '../domain/gauges.dart';
import '../models/realtime_flow.dart';
import '../models/river_run.dart';
import '../providers/gauges_provider.dart';
import '../providers/release_schedule_provider.dart';
import '../router.dart';
import '../theme/app_theme.dart';
import 'favourite_star.dart';
import 'flow_status_chip.dart';
import 'pebble.dart';

/// The best status among [runs] at [flow].
FlowStatus releaseStatus(Iterable<RiverRun> runs, double? flow) => flow == null
    ? FlowStatus.unknown
    : FlowStatus.best(runs.map((r) => r.flowStatus(flow)));

/// The flow a dam gauge's runs are judged on: the release now, or the
/// next one.
double? releaseFlowForGuide(WidgetRef ref, Gauge gauge) {
  final now = ref.watch(releaseClockProvider).valueOrNull ?? DateTime.now();
  final schedule = ref.watch(releaseScheduleProvider(gauge.id)).valueOrNull;
  return releaseOutlook(schedule, now).flow;
}

/// One river-time day as a 24-hour strip: released hours filled in
/// glacier blue (deeper for more water), with a tick at now on today.
class ReleaseDayBar extends StatelessWidget {
  const ReleaseDayBar({
    super.key,
    required this.day,
    required this.now,
    this.height = 14,
    this.maxFlow,
  });

  final ReleaseDay day;
  final DateTime now;
  final double height;

  /// The flow that fills an hour fully; the day's peak when null.
  final double? maxFlow;

  @override
  Widget build(BuildContext context) {
    final p = Riverstone.of(context);
    return ExcludeSemantics(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _DayBarPainter(
            day: day,
            now: now,
            track: p.faint,
            water: p.glacier,
            tick: p.ink,
            maxFlow: maxFlow,
          ),
        ),
      ),
    );
  }
}

class _DayBarPainter extends CustomPainter {
  _DayBarPainter({
    required this.day,
    required this.now,
    required this.track,
    required this.water,
    required this.tick,
    this.maxFlow,
  });

  final ReleaseDay day;
  final DateTime now;
  final Color track, water, tick;
  final double? maxFlow;

  @override
  void paint(Canvas canvas, Size size) {
    final r = Radius.circular(size.height / 2);
    final whole = RRect.fromRectAndRadius(Offset.zero & size, r);
    canvas.drawRRect(whole, Paint()..color = track);
    canvas.save();
    canvas.clipRRect(whole);
    final peak =
        maxFlow ?? day.hours.fold<double>(0, (m, h) => h.flow > m ? h.flow : m);
    double x(DateTime t) =>
        size.width *
        (t.difference(day.start).inMinutes / (24 * 60)).clamp(0.0, 1.0);
    for (final w in day.windows) {
      final strength = peak <= 0 ? 1.0 : (w.maxFlow / peak).clamp(0.55, 1.0);
      canvas.drawRect(
        Rect.fromLTRB(x(w.start), 0, x(w.end), size.height),
        Paint()..color = water.withValues(alpha: strength),
      );
    }
    canvas.restore();
    if (!now.isBefore(day.start) && now.isBefore(day.end)) {
      final nx = x(now);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(nx - 1.25, -3, nx + 1.25, size.height + 3),
          const Radius.circular(2),
        ),
        Paint()..color = tick,
      );
    }
  }

  @override
  bool shouldRepaint(_DayBarPainter old) =>
      old.day != day ||
      old.now != now ||
      old.track != track ||
      old.water != water ||
      old.maxFlow != maxFlow;
}

/// "Midnight · 6 AM · Noon · 6 PM" under a day bar.
class _HourTicks extends StatelessWidget {
  const _HourTicks();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final t in const ['12 AM', '6 AM', 'Noon', '6 PM'])
            Expanded(child: Text(t, style: style)),
        ],
      ),
    );
  }
}

/// A small "Dam release" badge, so a release tile reads differently from
/// a live gauge at a glance.
class DamReleaseBadge extends StatelessWidget {
  const DamReleaseBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: p.glacierSoft,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12, color: p.glacier),
          const SizedBox(width: 3),
          Text(
            'Dam release',
            style: theme.textTheme.labelSmall?.copyWith(
              color: p.glacier,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// A dam-release gauge in the Gauges list: what the dam is doing now or
/// next, judged for the runs below it, and today as a 24-hour strip.
class ReleaseGaugeRow extends ConsumerWidget {
  const ReleaseGaugeRow({super.key, required this.gauge});
  final Gauge gauge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final now = ref.watch(releaseClockProvider).valueOrNull ?? DateTime.now();
    final scheduleAsync = ref.watch(releaseScheduleProvider(gauge.id));
    final schedule = scheduleAsync.valueOrNull;
    final outlook = releaseOutlook(schedule, now);
    final status = releaseStatus(gauge.runs, outlook.flow);
    final today = schedule?.days(now).firstOrNull;
    final flow = outlook.flow;
    final caption = outlook.releasing
        ? 'now'
        : outlook.window != null
        ? 'at ${hourLabel(outlook.window!.start)}'
        : '';
    final position = ref.watch(devicePositionProvider).valueOrNull;
    final km = position == null ? null : gaugeDistanceKm(gauge, position);

    final label = [
      gauge.title,
      'Dam release',
      if (gauge.place.isNotEmpty) gauge.place,
      outlook.headline,
      outlook.detail,
      if (status != FlowStatus.unknown) status.label,
      if (km != null) distanceLabel(km),
    ].join(', ');

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: Pebble.a),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Semantics(
              button: true,
              label: label,
              excludeSemantics: true,
              child: InkWell(
                borderRadius: Pebble.a,
                onTap: () => context.go(AppRoutes.gauge(gauge.id)),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 4, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
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
                                const SizedBox(height: 6),
                                Text(
                                  outlook.headline,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: outlook.releasing
                                        ? p.glacier
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                if (!outlook.releasing &&
                                    outlook.window != null)
                                  Text(outlook.window!.timeText, style: muted)
                                else if (outlook.window == null &&
                                    !scheduleAsync.isLoading)
                                  Text(outlook.detail, style: muted),
                              ],
                            ),
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
                                    flow == null
                                        ? '–'
                                        : outlook.window!.flowText,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    caption.isEmpty ? 'm³/s' : 'm³/s $caption',
                                    style: muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const DamReleaseBadge(),
                          if (status != FlowStatus.unknown) ...[
                            const SizedBox(width: 6),
                            FlowStatusChip(status: status),
                          ],
                          const Spacer(),
                          if (km != null) Text(distanceLabel(km), style: muted),
                        ],
                      ),
                      if (today != null) ...[
                        const SizedBox(height: 10),
                        ReleaseDayBar(day: today, now: now, height: 10),
                        const SizedBox(height: 3),
                        const _HourTicks(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 4, top: 4),
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

const transAltaFlowsUrl =
    'https://transalta.com/our-operations/safety/river-flows';

/// The top of a dam-release gauge page: what the dam is doing now or
/// next, in big type, with a countdown. Tinted glacier blue while water is
/// coming down. With no schedule yet, says so and links to TransAlta.
class ReleaseNowCard extends ConsumerWidget {
  const ReleaseNowCard({super.key, required this.gauge});
  final Gauge gauge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final now = ref.watch(releaseClockProvider).valueOrNull ?? DateTime.now();
    final scheduleAsync = ref.watch(releaseScheduleProvider(gauge.id));
    final schedule = scheduleAsync.valueOrNull;
    final outlook = releaseOutlook(schedule, now);
    final status = releaseStatus(gauge.runs, outlook.flow);
    final countdown = releaseCountdown(outlook, now);
    final today = schedule?.days(now).firstOrNull;
    final missing = !scheduleAsync.isLoading && (schedule?.isEmpty ?? true);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: outlook.releasing
            ? Color.alphaBlend(
                p.glacierSoft.withValues(alpha: 0.7),
                theme.colorScheme.surfaceContainerLow,
              )
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: Pebble.a,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const DamReleaseBadge(),
              const Spacer(),
              if (status != FlowStatus.unknown) FlowStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 14),
          if (missing) ...[
            Row(
              children: [
                Icon(Icons.hourglass_empty, color: p.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    outlook.headline,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'TransAlta posts release times for today and the next four '
              'days. They show up here as soon as they are read in.',
              style: muted,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => launchUrl(
                  Uri.parse(transAltaFlowsUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text("TransAlta's river flows"),
              ),
            ),
          ] else ...[
            Text(
              outlook.headline,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: outlook.releasing ? p.glacier : null,
              ),
            ),
            if (outlook.window case final w?) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    w.flowText,
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'm³/s',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                outlook.releasing
                    ? '${hourLabel(w.start)} to ${hourLabel(w.end)}'
                    : w.timeText,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (countdown != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: outlook.releasing ? p.glacier : p.faint,
                      borderRadius: Pebble.pill,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: outlook.releasing ? p.card : p.ink,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          countdown,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: outlook.releasing ? p.card : p.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ] else if (!scheduleAsync.isLoading)
              Text(outlook.detail, style: muted),
            if (today != null) ...[
              const SizedBox(height: 16),
              ReleaseDayBar(day: today, now: now, height: 14),
              const SizedBox(height: 4),
              const _HourTicks(),
            ],
          ],
        ],
      ),
    );
  }
}

/// The published days, one row each, with the source's caveats. Nothing
/// when there's no schedule (the now card already says so).
class ReleaseWeekCard extends ConsumerWidget {
  const ReleaseWeekCard({super.key, required this.gauge});
  final Gauge gauge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final now = ref.watch(releaseClockProvider).valueOrNull ?? DateTime.now();
    final schedule = ref.watch(releaseScheduleProvider(gauge.id)).valueOrNull;
    final days = schedule?.days(now) ?? const <ReleaseDay>[];
    if (days.isEmpty) return const SizedBox.shrink();
    final peak = [
      for (final d in days) ...d.hours.map((h) => h.flow),
    ].fold<double>(0, (m, f) => f > m ? f : m);
    final note = ref.watch(stationsProvider).valueOrNull?[gauge.id]?.note;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        const SectionLabel('Release schedule'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: Pebble.b,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final day in days) ...[
                _DayRow(day: day, now: now, peak: peak),
                const SizedBox(height: 12),
              ],
              const Padding(
                padding: EdgeInsets.only(left: 92),
                child: _HourTicks(),
              ),
              const SizedBox(height: 14),
              Text(
                [
                  'Planned by TransAlta, in Alberta time. Flows can change '
                      'without notice, so check at the river.',
                  ?note,
                ].join(' '),
                style: muted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The last two weeks as a column per day: how much the dam released, or
/// a dot on days it didn't. Only once there are a few days to show.
class ReleaseHistoryCard extends StatelessWidget {
  const ReleaseHistoryCard({
    super.key,
    required this.readings,
    required this.now,
    this.days = 14,
  });

  final List<FlowReading> readings;
  final DateTime now;
  final int days;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    final muted = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final peaks = {
      for (final d in dailyReleasePeaks(hourlyWindow(readings, days)))
        d.time: d.flow,
    };
    if (peaks.length < 2) return const SizedBox.shrink();
    final w = riverWall(now);
    final todayStart = DateTime.utc(
      w.year,
      w.month,
      w.day,
    ).subtract(releaseUtcOffset);
    final columns = [
      for (var i = days - 1; i >= 0; i--)
        todayStart.subtract(Duration(days: i)),
    ];
    final top = peaks.values.fold<double>(1, (m, f) => f > m ? f : m);
    final released = columns.where((d) => (peaks[d] ?? 0) > 0).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        const SectionLabel('Last two weeks'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: Pebble.a,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                released == 1
                    ? 'Released on 1 day'
                    : 'Released on $released days',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Semantics(
                label: [
                  for (final d in columns)
                    if (peaks[d] case final f?)
                      '${dayLabel(d, now)}: ${f > 0 ? '${f.round()} cubic metres per second' : 'no release'}',
                ].join(', '),
                excludeSemantics: true,
                child: SizedBox(
                  height: 108,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final d in columns)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                if (peaks[d] case final f? when f > 0) ...[
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      f.round().toString(),
                                      style: muted,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Container(
                                    height: 56 * (f / top).clamp(0.15, 1.0),
                                    decoration: BoxDecoration(
                                      color: p.glacier,
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(4),
                                        bottom: Radius.circular(2),
                                      ),
                                    ),
                                  ),
                                ] else
                                  Container(
                                    width: 5,
                                    height: 5,
                                    margin: const EdgeInsets.only(bottom: 2),
                                    decoration: BoxDecoration(
                                      color: peaks.containsKey(d)
                                          ? p.muted
                                          : p.faint,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  DateFormat('E').format(riverWall(d))[0],
                                  style: muted?.copyWith(
                                    fontWeight: d == todayStart
                                        ? FontWeight.w900
                                        : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.now, required this.peak});
  final ReleaseDay day;
  final DateTime now;
  final double peak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final windows = day.windows;
    final name = dayLabel(day.start, now);
    final summary = windows.isEmpty
        ? 'No release'
        : windows.map((w) => '${w.timeText} · ${w.flowText}').join(', ');
    return Semantics(
      label:
          '$name: ${windows.isEmpty ? 'no release' : windows.map((w) => '${w.timeText} at ${w.flowText} cubic metres per second').join(', ')}',
      excludeSemantics: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              name.contains(',') ? name.split(', ').first : name,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: ReleaseDayBar(
                    day: day,
                    now: now,
                    height: 12,
                    maxFlow: peak > 0 ? peak : null,
                  ),
                ),
                const SizedBox(height: 4),
                Text(windows.isEmpty ? summary : '$summary m³/s', style: muted),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The flow card on a run page, for a run below a dam: what's released
/// now or next, judged for this run, and today's strip. Taps through to
/// the full schedule.
class ReleaseRunConditions extends ConsumerWidget {
  const ReleaseRunConditions({
    super.key,
    required this.run,
    required this.gaugeId,
    required this.footer,
    this.guide,
  });

  final RiverRun run;
  final String gaugeId;

  /// The run's flow guide strip, pinned at the release flow.
  final Widget Function(FlowStatus status, double? flow)? guide;

  /// The gauge link row at the bottom.
  final Widget footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final now = ref.watch(releaseClockProvider).valueOrNull ?? DateTime.now();
    final schedule = ref.watch(releaseScheduleProvider(gaugeId)).valueOrNull;
    final outlook = releaseOutlook(schedule, now);
    final status = run.flowStatus(outlook.flow);
    final today = schedule?.days(now).firstOrNull;

    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: Pebble.a),
      child: InkWell(
        borderRadius: Pebble.a,
        onTap: () => context.push(AppRoutes.gauge(gaugeId)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const DamReleaseBadge(),
                  const Spacer(),
                  if (status != FlowStatus.unknown)
                    FlowStatusChip(status: status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                outlook.headline,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: outlook.releasing ? p.glacier : null,
                ),
              ),
              Text(outlook.detail, style: muted),
              if (today != null) ...[
                const SizedBox(height: 10),
                ReleaseDayBar(day: today, now: now, height: 10),
                const SizedBox(height: 3),
                const _HourTicks(),
              ],
              if (guide != null) ...[
                const SizedBox(height: 14),
                guide!(status, outlook.flow),
              ],
              const Divider(height: 24),
              footer,
            ],
          ),
        ),
      ),
    );
  }
}
