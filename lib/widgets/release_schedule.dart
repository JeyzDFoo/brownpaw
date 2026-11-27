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
import '../theme/flow_status_style.dart';
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

/// The release schedule as a calendar: a week per row, each day showing
/// the flow and hours the dam released (recorded) or will release
/// (published), coloured by how that flow suits the runs below. Tap a day
/// for its details.
class ReleaseCalendarCard extends ConsumerStatefulWidget {
  const ReleaseCalendarCard({
    super.key,
    required this.gauge,
    required this.readings,
  });

  final Gauge gauge;

  /// Recorded hourly flows, for the days already past.
  final List<FlowReading> readings;

  @override
  ConsumerState<ReleaseCalendarCard> createState() =>
      _ReleaseCalendarCardState();
}

class _ReleaseCalendarCardState extends ConsumerState<ReleaseCalendarCard> {
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final now = ref.watch(releaseClockProvider).valueOrNull ?? DateTime.now();
    final schedule = ref
        .watch(releaseScheduleProvider(widget.gauge.id))
        .valueOrNull;
    final history = [
      for (final r in widget.readings)
        if (r.discharge != null)
          (start: r.timestamp.toUtc(), flow: r.discharge!),
    ];
    final days = releaseCalendar(history, schedule, now);
    if (days.isEmpty) return const SizedBox.shrink();
    final note = ref
        .watch(stationsProvider)
        .valueOrNull?[widget.gauge.id]
        ?.note;

    final today = riverDayStart(now);
    // Two weeks back at most, through the end of what's published, in
    // whole Sunday-to-Saturday weeks.
    var first = days.keys.reduce((a, b) => a.isBefore(b) ? a : b);
    final floor = today.subtract(const Duration(days: 13));
    if (first.isBefore(floor)) first = floor;
    if (first.isAfter(today)) first = today;
    var last = days.keys.reduce((a, b) => a.isAfter(b) ? a : b);
    if (last.isBefore(today)) last = today;
    first = first.subtract(Duration(days: riverWall(first).weekday % 7));
    last = last.add(Duration(days: 6 - riverWall(last).weekday % 7));
    final cells = [
      for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1)))
        d,
    ];
    final selected = _selected ?? today;
    final months = {
      for (final d in cells) DateFormat('MMMM y').format(riverWall(d)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        const SectionLabel('Release calendar'),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLow,
            borderRadius: Pebble.b,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  months.length == 1
                      ? months.single
                      : '${months.first.split(' ').first} – ${months.last}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              ExcludeSemantics(
                child: Row(
                  children: [
                    for (final d in const ['S', 'M', 'T', 'W', 'T', 'F', 'S'])
                      Expanded(
                        child: Text(
                          d,
                          textAlign: TextAlign.center,
                          style: muted?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              for (var row = 0; row < cells.length ~/ 7; row++)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      for (final d in cells.skip(row * 7).take(7))
                        Expanded(
                          child: _CalendarCell(
                            day: d,
                            data: days[d],
                            runs: widget.gauge.runs,
                            isToday: d == today,
                            selected: d == selected,
                            now: now,
                            onTap: () => setState(() => _selected = d),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              _CalendarDetail(
                day: selected,
                data: days[selected],
                runs: widget.gauge.runs,
                now: now,
                isToday: selected == today,
              ),
              const SizedBox(height: 12),
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

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.day,
    required this.data,
    required this.runs,
    required this.isToday,
    required this.selected,
    required this.now,
    required this.onTap,
  });

  final DateTime day;
  final ReleaseCalendarDay? data;
  final List<RiverRun> runs;
  final bool isToday;
  final bool selected;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    final small = theme.textTheme.labelSmall;
    final peak = data?.peak;
    final status = releaseStatus(runs, peak);
    final tint = status == FlowStatus.unknown
        ? p.glacier
        : status.color(context);
    final past = data != null && !data!.planned;
    final w = data?.windows.firstOrNull;

    final label = [
      dayLabel(day, now),
      if (data == null)
        'no information'
      else if (w == null)
        'no release'
      else
        '${w.timeText}, ${w.flowText} cubic metres per second',
      if (status != FlowStatus.unknown) status.label,
    ].join(', ');

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 74,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected ? p.ink : Colors.transparent,
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(2, 4, 2, 4),
              child: Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: isToday
                        ? BoxDecoration(color: p.accent, shape: BoxShape.circle)
                        : null,
                    child: Text(
                      '${riverWall(day).day}',
                      style: small?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isToday
                            ? p.card
                            : data == null
                            ? p.muted.withValues(alpha: 0.6)
                            : p.ink,
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (w != null)
                    Opacity(
                      opacity: past ? 0.6 : 1,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        decoration: BoxDecoration(
                          color: tint.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                w.flowText,
                                style: theme.textTheme.labelLarge?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: tint,
                                  height: 1.1,
                                ),
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                shortRange(w),
                                style: small?.copyWith(
                                  fontSize: 10,
                                  color: p.muted,
                                  height: 1.1,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (data != null)
                    Text('Off', style: small?.copyWith(color: p.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CalendarDetail extends StatelessWidget {
  const _CalendarDetail({
    required this.day,
    required this.data,
    required this.runs,
    required this.now,
    required this.isToday,
  });

  final DateTime day;
  final ReleaseCalendarDay? data;
  final List<RiverRun> runs;
  final DateTime now;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final name = DateFormat('EEEE, MMM d').format(riverWall(day));
    final status = releaseStatus(runs, data?.peak);
    final windows = data?.windows ?? const <ReleaseWindow>[];
    final String text;
    if (data == null) {
      text = day.isAfter(now)
          ? "TransAlta hasn't published this day yet."
          : 'No record for this day.';
    } else if (windows.isEmpty) {
      text = data!.planned ? 'No release planned.' : 'No release.';
    } else {
      final verb = data!.planned ? 'Planned' : 'Released';
      text = windows
          .map(
            (w) => '$verb ${w.timeText} at ${w.flowText}\u00a0m³\u2060/\u2060s',
          )
          .join('\n');
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          p.faint.withValues(alpha: 0.5),
          theme.colorScheme.surfaceContainerLow,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isToday ? 'Today · $name' : name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(text, style: muted),
              ],
            ),
          ),
          if (status != FlowStatus.unknown) ...[
            const SizedBox(width: 8),
            FlowStatusChip(status: status),
          ],
        ],
      ),
    );
  }
}
