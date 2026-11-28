import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:url_launcher/url_launcher.dart';

import '../domain/flow_status.dart';
import '../domain/gauges.dart';
import '../domain/tidal.dart';
import '../models/river_run.dart';
import '../providers/gauges_provider.dart';
import '../providers/release_schedule_provider.dart';
import '../providers/tidal_provider.dart';
import '../router.dart';
import '../theme/app_theme.dart';
import '../theme/flow_status_style.dart';
import 'favourite_star.dart';
import 'flow_status_chip.dart';
import 'pebble.dart';
import 'release_schedule.dart' show releaseStatus;

/// Where a tidal gauge is, for sunrise and sunset: its first run's pin,
/// else Sechelt Rapids.
(double, double) tidalLatLon(Iterable<RiverRun> runs) {
  for (final r in runs) {
    final c = r.coordinates ?? r.putInCoordinates;
    final lat = c?['latitude'], lon = c?['longitude'];
    if (lat != null && lon != null) return (lat, lon);
  }
  return (49.7383, -123.8983);
}

/// The knots a tidal gauge's runs are judged on: the flood now or next.
double? tidalFlowForGuide(WidgetRef ref, Gauge gauge) {
  final now = ref.watch(releaseClockProvider).valueOrNull ?? DateTime.now();
  final p = ref.watch(tidalPredictionsProvider(gauge.id)).valueOrNull;
  final (lat, lon) = tidalLatLon(gauge.runs);
  return tidalOutlook(p, now, lat: lat, lon: lon).knots;
}

/// The first run on a tidal gauge with a guide link (`sourceUrl`).
RiverRun? tidalGuideRun(Iterable<RiverRun> runs) {
  for (final r in runs) {
    final url = r.sourceUrl?.trim();
    if (url != null && url.isNotEmpty && Uri.tryParse(url) != null) return r;
  }
  return null;
}

/// "Skook Surfing 101": the spot's local guide (the run's `source` and
/// `sourceUrl`), opened in the browser.
class TidalGuideLink extends StatelessWidget {
  const TidalGuideLink({super.key, required this.run});
  final RiverRun run;

  @override
  Widget build(BuildContext context) {
    final url = run.sourceUrl!.trim();
    final source = run.source?.trim();
    final name = source == null || source.isEmpty
        ? (Uri.tryParse(url)?.host ?? 'the guide')
        : source;
    return Align(
      alignment: Alignment.centerLeft,
      child: FilledButton.tonalIcon(
        onPressed: () =>
            launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
        icon: const Icon(Icons.menu_book_outlined, size: 18),
        label: Text(name),
      ),
    );
  }
}

const dairikiUrl = 'https://www.dairiki.org/tides/monthly.php/scl';

/// A small "Tidal" badge, so a tidal tile reads differently from a river
/// gauge at a glance.
class TidalBadge extends StatelessWidget {
  const TidalBadge({super.key});

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
          Icon(Icons.waves, size: 12, color: p.glacier),
          const SizedBox(width: 3),
          Text(
            'Tidal',
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

/// "12 AM · 6 AM · Noon · 6 PM" under a day curve.
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

/// One BC day of current: flood above the line in glacier blue, ebb below
/// in a muted tone, night shaded, the max floods labelled in knots, slacks
/// dotted on the line and a tick at now. With [showTide], the tide height
/// runs underneath as a thin line with its highs and lows.
class TidalDayCurve extends StatelessWidget {
  const TidalDayCurve({
    super.key,
    required this.predictions,
    required this.dayStart,
    required this.now,
    required this.lat,
    required this.lon,
    this.height = 120,
    this.showTide = true,
    this.labels = true,
  });

  final TidalPredictions predictions;
  final DateTime dayStart;
  final DateTime now;
  final double lat, lon;
  final double height;
  final bool showTide;
  final bool labels;

  @override
  Widget build(BuildContext context) {
    final p = Riverstone.of(context);
    final theme = Theme.of(context);
    final tide = showTide && predictions.tidesOn(dayStart).isNotEmpty;
    return ExcludeSemantics(
      child: SizedBox(
        height: height + (tide ? 52 : 0),
        width: double.infinity,
        child: CustomPaint(
          painter: _CurvePainter(
            p: predictions,
            day: dayStart,
            now: now,
            sun: sunTimes(dayStart, lat, lon),
            curveHeight: height,
            tide: tide,
            labels: labels,
            flood: p.glacier,
            ebb: p.muted,
            night: p.faint,
            ink: p.ink,
            muted: p.muted,
            accent: p.accent,
            text: theme.textTheme.labelSmall ?? const TextStyle(fontSize: 11),
          ),
        ),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.p,
    required this.day,
    required this.now,
    required this.sun,
    required this.curveHeight,
    required this.tide,
    required this.labels,
    required this.flood,
    required this.ebb,
    required this.night,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.text,
  });

  final TidalPredictions p;
  final DateTime day, now;
  final (DateTime, DateTime) sun;
  final double curveHeight;
  final bool tide, labels;
  final Color flood, ebb, night, ink, muted, accent;
  final TextStyle text;

  static const _step = Duration(minutes: 10);

  @override
  void paint(Canvas canvas, Size size) {
    final end = day.add(const Duration(days: 1));
    double x(DateTime t) =>
        size.width * (t.difference(day).inMinutes / (24 * 60)).clamp(0.0, 1.0);
    final top = labels ? 16.0 : 4.0;
    final h = curveHeight - top;

    // Scale to the bigger of the day's flood and ebb, at least 6 kt, so a
    // small day looks small.
    var peak = 6.0;
    for (final e in p.currents) {
      if (e.time.isAfter(day.subtract(const Duration(hours: 6))) &&
          e.time.isBefore(end.add(const Duration(hours: 6)))) {
        peak = math.max(peak, e.knots);
      }
    }
    // Floods get more room than ebbs: they're what the wave is made of.
    final mid = top + h * 0.62;
    double y(double v) => v >= 0
        ? mid - (v / peak) * (mid - top)
        : mid - (v / peak) * (top + h - mid);

    // Night.
    final nightPaint = Paint()..color = night.withValues(alpha: 0.55);
    canvas.drawRect(Rect.fromLTRB(0, 0, x(sun.$1), curveHeight), nightPaint);
    canvas.drawRect(
      Rect.fromLTRB(x(sun.$2), 0, size.width, curveHeight),
      nightPaint,
    );

    // Curve.
    final pts = <Offset>[];
    for (var t = day; !t.isAfter(end); t = t.add(_step)) {
      final v = p.speedAt(t);
      if (v != null) pts.add(Offset(x(t), y(v)));
    }
    if (pts.length > 1) {
      final up = Path()..moveTo(pts.first.dx, mid);
      for (final o in pts) {
        up.lineTo(o.dx, math.min(o.dy, mid));
      }
      up
        ..lineTo(pts.last.dx, mid)
        ..close();
      canvas.drawPath(up, Paint()..color = flood.withValues(alpha: 0.28));
      final down = Path()..moveTo(pts.first.dx, mid);
      for (final o in pts) {
        down.lineTo(o.dx, math.max(o.dy, mid));
      }
      down
        ..lineTo(pts.last.dx, mid)
        ..close();
      canvas.drawPath(down, Paint()..color = ebb.withValues(alpha: 0.18));
      final line = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        line.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
        line,
        Paint()
          ..color = flood
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round,
      );
    }

    // Slack line.
    canvas.drawLine(
      Offset(0, mid),
      Offset(size.width, mid),
      Paint()
        ..color = muted.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );

    for (final e in p.currentsOn(day)) {
      final o = Offset(x(e.time), y(e.signed));
      if (e.isSlack) {
        canvas.drawCircle(o, 3, Paint()..color = ink);
      } else if (labels) {
        final label = TextPainter(
          text: TextSpan(
            text: knotsText(e.knots),
            style: text.copyWith(
              color: e.isFlood ? flood : muted,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final dx = (o.dx - label.width / 2).clamp(
          0.0,
          size.width - label.width,
        );
        final dy = e.isFlood ? o.dy - label.height - 1 : o.dy + 2;
        label.paint(
          canvas,
          Offset(dx, dy.clamp(0.0, curveHeight - label.height)),
        );
      }
    }

    // Now.
    if (!now.isBefore(day) && now.isBefore(end)) {
      final nx = x(now);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(nx - 1.25, 0, nx + 1.25, curveHeight),
          const Radius.circular(2),
        ),
        Paint()..color = accent,
      );
    }

    if (!tide) return;
    // Tide underneath.
    final t0 = curveHeight + 16, t1 = curveHeight + 34;
    double lo = double.infinity, hi = -double.infinity;
    for (final e in p.tides) {
      if (e.time.isAfter(day.subtract(const Duration(hours: 8))) &&
          e.time.isBefore(end.add(const Duration(hours: 8)))) {
        lo = math.min(lo, e.metres);
        hi = math.max(hi, e.metres);
      }
    }
    if (!lo.isFinite || hi <= lo) return;
    double ty(double m) => t1 - (m - lo) / (hi - lo) * (t1 - t0);
    final tidePath = Path();
    var started = false;
    for (var t = day; !t.isAfter(end); t = t.add(_step)) {
      final m = p.tideAt(t);
      if (m == null) continue;
      if (!started) {
        tidePath.moveTo(x(t), ty(m));
        started = true;
      } else {
        tidePath.lineTo(x(t), ty(m));
      }
    }
    canvas.drawPath(
      tidePath,
      Paint()
        ..color = muted
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    for (final e in p.tidesOn(day)) {
      final o = Offset(x(e.time), ty(e.metres));
      canvas.drawCircle(o, 2.5, Paint()..color = muted);
      final label = TextPainter(
        text: TextSpan(
          text: '${e.metres.toStringAsFixed(1)} m',
          style: text.copyWith(color: muted, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = (o.dx - label.width / 2).clamp(0.0, size.width - label.width);
      final dy = e.high ? o.dy - label.height - 1 : o.dy + 2;
      label.paint(
        canvas,
        Offset(dx, dy.clamp(curveHeight, size.height - label.height)),
      );
    }
  }

  @override
  bool shouldRepaint(_CurvePainter old) =>
      old.p != p ||
      old.day != day ||
      old.now != now ||
      old.flood != flood ||
      old.curveHeight != curveHeight;
}

/// A tidal spot in the Gauges list: the next max flood, judged for the
/// runs there, with today's curve.
class TidalGaugeRow extends ConsumerWidget {
  const TidalGaugeRow({super.key, required this.gauge});
  final Gauge gauge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final now = ref.watch(releaseClockProvider).valueOrNull ?? DateTime.now();
    final async = ref.watch(tidalPredictionsProvider(gauge.id));
    final pred = async.valueOrNull;
    final (lat, lon) = tidalLatLon(gauge.runs);
    final outlook = tidalOutlook(pred, now, lat: lat, lon: lon);
    final status = releaseStatus(gauge.runs, outlook.knots);
    final position = ref.watch(devicePositionProvider).valueOrNull;
    final km = position == null ? null : gaugeDistanceKm(gauge, position);
    final f = outlook.flood;

    final label = [
      gauge.title,
      'Tidal',
      if (gauge.place.isNotEmpty) gauge.place,
      outlook.headline,
      if (f != null) '${knotsText(f.knots)} knots',
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
                                    color: outlook.flooding ? p.glacier : null,
                                  ),
                                ),
                                if (!async.isLoading)
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
                                    f == null ? '–' : knotsText(f.knots),
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    f == null
                                        ? 'kt'
                                        : 'kt at ${tidalShortTime(f.time)}',
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
                          const TidalBadge(),
                          if (status != FlowStatus.unknown) ...[
                            const SizedBox(width: 6),
                            FlowStatusChip(status: status),
                          ],
                          const Spacer(),
                          if (km != null) Text(distanceLabel(km), style: muted),
                        ],
                      ),
                      if (pred != null) ...[
                        const SizedBox(height: 10),
                        TidalDayCurve(
                          predictions: pred,
                          dayStart: tidalDayStart(now),
                          now: now,
                          lat: lat,
                          lon: lon,
                          height: 44,
                          showTide: false,
                          labels: false,
                        ),
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

/// "today", "tomorrow", or the date as is, for mid-sentence.
String _lowerRelative(String day) =>
    day == 'Today' || day == 'Tomorrow' ? day.toLowerCase() : day;

/// A countdown pill: "Peaks in 2 h 10 min".
class _Countdown extends StatelessWidget {
  const _Countdown(this.text, {required this.strong});
  final String text;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: strong ? p.glacier : p.faint,
        borderRadius: Pebble.pill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.timer_outlined, size: 16, color: strong ? p.card : p.ink),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: strong ? p.card : p.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A label and value side by side: "Slack · 5:30 AM".
class _Fact extends StatelessWidget {
  const _Fact(this.label, this.value);
  final String label, value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

/// The top of a tidal gauge page: the next max flood in big type, when it
/// peaks and the slack either side (the surf window), how the ebb before
/// compares, a countdown, and today's curve with the tide.
class TidalNowCard extends ConsumerWidget {
  const TidalNowCard({super.key, required this.gauge});
  final Gauge gauge;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final now = ref.watch(releaseClockProvider).valueOrNull ?? DateTime.now();
    final async = ref.watch(tidalPredictionsProvider(gauge.id));
    final pred = async.valueOrNull;
    final (lat, lon) = tidalLatLon(gauge.runs);
    final outlook = tidalOutlook(pred, now, lat: lat, lon: lon);
    final status = releaseStatus(gauge.runs, outlook.knots);
    final countdown = tidalCountdown(outlook, now);
    final f = outlook.flood;
    final missing = !async.isLoading && pred == null;
    final dark = f != null && !isDaylight(f.time, lat, lon);
    final daylight = dark && pred != null
        ? pred.nextDaylightFlood(now, lat, lon)
        : null;
    final speed = outlook.speedNow;
    final ebb = f == null ? null : ebbNote(f);

    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: BoxDecoration(
        color: outlook.flooding
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
              const TidalBadge(),
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
              'Current predictions for Sechelt Rapids show up here as soon '
              'as they are read in.',
              style: muted,
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: () => launchUrl(
                  Uri.parse(dairikiUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: const Text('Current table on dairiki.org'),
              ),
            ),
          ] else if (pred != null) ...[
            Text(
              outlook.headline,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: outlook.flooding ? p.glacier : null,
              ),
            ),
            if (f != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    knotsText(f.knots),
                    style: theme.textTheme.displayMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'kt',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${tidalDayLabel(f.time, now)} at ${tidalTime(f.time)}',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (dark)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    daylight == null
                        ? 'Peaks after dark.'
                        : 'Peaks after dark. Next in daylight: '
                              '${knotsText(daylight.knots)} kt, '
                              '${_lowerRelative(tidalDayLabel(daylight.time, now))} '
                              'at ${tidalTime(daylight.time)}.',
                    style: muted?.copyWith(color: p.low),
                  ),
                ),
              if (countdown != null) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: _Countdown(countdown, strong: outlook.flooding),
                ),
              ],
              const SizedBox(height: 14),
              Wrap(
                spacing: 22,
                runSpacing: 8,
                children: [
                  if (f.start != null)
                    _Fact('SLACK BEFORE', tidalTime(f.start!)),
                  if (f.end != null) _Fact('SLACK AFTER', tidalTime(f.end!)),
                  if (speed != null)
                    _Fact(
                      'NOW',
                      speed.abs() < 0.5
                          ? 'Slack'
                          : '${knotsText(speed.abs())} kt '
                                '${speed > 0 ? 'flood' : 'ebb'}',
                    ),
                ],
              ),
              if (ebb != null) ...[
                const SizedBox(height: 8),
                Text(ebb, style: muted),
              ],
            ] else
              Text(outlook.detail, style: muted),
            const SizedBox(height: 16),
            TidalDayCurve(
              predictions: pred,
              dayStart: tidalDayStart(now),
              now: now,
              lat: lat,
              lon: lon,
            ),
            const SizedBox(height: 4),
            const _HourTicks(),
            const SizedBox(height: 8),
            Text(
              [
                'Current at Sechelt Rapids, flood above the line',
                if (pred.tides.isNotEmpty)
                  'tide at ${pred.tideStation ?? 'Egmont'} below',
              ].join('; '),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The flow card on a run page, for a tidal spot: the next max flood,
/// judged for this run, and today's curve. Taps through to the gauge.
class TidalRunConditions extends ConsumerWidget {
  const TidalRunConditions({
    super.key,
    required this.run,
    required this.gaugeId,
    required this.footer,
    this.guide,
  });

  final RiverRun run;
  final String gaugeId;
  final Widget Function(FlowStatus status, double? flow)? guide;
  final Widget footer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final now = ref.watch(releaseClockProvider).valueOrNull ?? DateTime.now();
    final pred = ref.watch(tidalPredictionsProvider(gaugeId)).valueOrNull;
    final (lat, lon) = tidalLatLon([run]);
    final outlook = tidalOutlook(pred, now, lat: lat, lon: lon);
    final status = run.flowStatus(outlook.knots);
    final f = outlook.flood;

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
                  const TidalBadge(),
                  const Spacer(),
                  if (status != FlowStatus.unknown)
                    FlowStatusChip(status: status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                f == null
                    ? outlook.headline
                    : '${outlook.headline}: ${knotsText(f.knots)} kt',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: outlook.flooding ? p.glacier : null,
                ),
              ),
              Text(outlook.detail, style: muted),
              if (pred != null) ...[
                const SizedBox(height: 10),
                TidalDayCurve(
                  predictions: pred,
                  dayStart: tidalDayStart(now),
                  now: now,
                  lat: lat,
                  lon: lon,
                  height: 70,
                  showTide: false,
                ),
                const SizedBox(height: 3),
                const _HourTicks(),
              ],
              if (guide != null) ...[
                const SizedBox(height: 14),
                guide!(status, outlook.knots),
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

/// The floods as a calendar: a week per row, each day showing its biggest
/// max flood in daylight and when, coloured by how it suits the runs here.
/// Tap a day for its curve, slacks and tides.
class TidalCalendarCard extends ConsumerStatefulWidget {
  const TidalCalendarCard({super.key, required this.gauge});
  final Gauge gauge;

  @override
  ConsumerState<TidalCalendarCard> createState() => _TidalCalendarCardState();
}

class _TidalCalendarCardState extends ConsumerState<TidalCalendarCard> {
  DateTime? _selected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final now = ref.watch(releaseClockProvider).valueOrNull ?? DateTime.now();
    final pred = ref
        .watch(tidalPredictionsProvider(widget.gauge.id))
        .valueOrNull;
    if (pred == null) return const SizedBox.shrink();
    final (lat, lon) = tidalLatLon(widget.gauge.runs);
    final today = tidalDayStart(now);
    final days = pred.days(from: today);
    if (days.isEmpty) return const SizedBox.shrink();

    // From this week's Sunday through four more weeks, in whole weeks.
    var first = today.subtract(Duration(days: tidalWall(today).weekday % 7));
    var last = days.last;
    final cap = first.add(const Duration(days: 34));
    if (last.isAfter(cap)) last = cap;
    last = last.add(Duration(days: 6 - tidalWall(last).weekday % 7));
    final cells = [
      for (var d = first; !d.isAfter(last); d = d.add(const Duration(days: 1)))
        d,
    ];
    final covered = {for (final d in days) d};
    final selected = _selected ?? today;
    final months = {
      for (final d in cells) DateFormat('MMMM y').format(tidalWall(d)),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 22),
        const SectionLabel('Flood calendar'),
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
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
                child: Text(
                  "Each day's biggest max flood in daylight.",
                  style: muted,
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
                          child: _TidalCell(
                            day: d,
                            flood: covered.contains(d) && !d.isBefore(today)
                                ? pred.bestDaylightFlood(d, lat, lon)
                                : null,
                            known: covered.contains(d) && !d.isBefore(today),
                            runs: widget.gauge.runs,
                            isToday: d == today,
                            selected: d == selected,
                            now: now,
                            onTap: d.isBefore(today)
                                ? null
                                : () => setState(() => _selected = d),
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),
              _TidalDayDetail(
                predictions: pred,
                day: selected,
                now: now,
                runs: widget.gauge.runs,
                lat: lat,
                lon: lon,
              ),
              const SizedBox(height: 12),
              Text(
                'Predictions from ${pred.sourceName}'
                '${pred.tides.isNotEmpty ? ', tides at ${pred.tideStation ?? 'Egmont'} from the Canadian Hydrographic Service' : ''}. '
                'BC time. Predictions, not measurements: wind and rain '
                'change things, so check at the water.',
                style: muted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TidalCell extends StatelessWidget {
  const _TidalCell({
    required this.day,
    required this.flood,
    required this.known,
    required this.runs,
    required this.isToday,
    required this.selected,
    required this.now,
    required this.onTap,
  });

  final DateTime day;
  final Flood? flood;
  final bool known;
  final List<RiverRun> runs;
  final bool isToday, selected;
  final DateTime now;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    final small = theme.textTheme.labelSmall;
    final f = flood;
    final status = releaseStatus(runs, f?.knots);
    final tint = status == FlowStatus.unknown
        ? p.glacier
        : status.color(context);

    final label = [
      tidalDayLabel(day, now),
      if (!known)
        'no prediction'
      else if (f == null)
        'no daylight flood'
      else
        'max flood ${knotsText(f.knots)} knots at ${tidalTime(f.time)}',
      if (status != FlowStatus.unknown) status.label,
    ].join(', ');

    return Semantics(
      button: onTap != null,
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
                      '${tidalWall(day).day}',
                      style: small?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: isToday
                            ? p.card
                            : known
                            ? p.ink
                            : p.muted.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  const Spacer(),
                  if (f != null)
                    Container(
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
                              knotsText(f.knots),
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
                              tidalShortTime(f.time),
                              style: small?.copyWith(
                                fontSize: 10,
                                color: p.muted,
                                height: 1.1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (known)
                    Text('Dark', style: small?.copyWith(color: p.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One day in full: its curve with the tide, each flood with its slacks,
/// and the highs and lows.
class _TidalDayDetail extends StatelessWidget {
  const _TidalDayDetail({
    required this.predictions,
    required this.day,
    required this.now,
    required this.runs,
    required this.lat,
    required this.lon,
  });

  final TidalPredictions predictions;
  final DateTime day, now;
  final List<RiverRun> runs;
  final double lat, lon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = Riverstone.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final name = DateFormat('EEEE, MMM d').format(tidalWall(day));
    final isToday = day == tidalDayStart(now);
    final best = predictions.bestDaylightFlood(day, lat, lon);
    final status = releaseStatus(runs, best?.knots);
    final floods = predictions.floodsOn(day);
    final tides = predictions.tidesOn(day);
    final (rise, set) = sunTimes(day, lat, lon);

    String floodLine(Flood f) {
      final parts = [
        '${knotsText(f.knots)} kt at ${tidalTime(f.time)}',
        if (f.start != null && f.end != null)
          'slack ${tidalTime(f.start!)} to ${tidalTime(f.end!)}',
        if (!isDaylight(f.time, lat, lon)) 'dark',
      ];
      return 'Flood ${parts.join(' · ')}';
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  isToday ? 'Today · $name' : name,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (status != FlowStatus.unknown) FlowStatusChip(status: status),
            ],
          ),
          const SizedBox(height: 10),
          TidalDayCurve(
            predictions: predictions,
            dayStart: day,
            now: now,
            lat: lat,
            lon: lon,
            height: 100,
          ),
          const SizedBox(height: 4),
          const _HourTicks(),
          const SizedBox(height: 10),
          if (floods.isEmpty)
            Text('No flood predicted.', style: muted)
          else
            for (final f in floods)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  floodLine(f),
                  style: (f == best
                      ? theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        )
                      : muted),
                ),
              ),
          if (best == null ? null : ebbNote(best) case final note?)
            Text(note, style: muted),
          if (tides.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              tides
                  .map(
                    (t) =>
                        '${t.high ? 'High' : 'Low'} ${t.metres.toStringAsFixed(1)} m '
                        '${tidalTime(t.time)}',
                  )
                  .join(' · '),
              style: muted,
            ),
          ],
          const SizedBox(height: 6),
          Text(
            'Sunrise ${tidalTime(rise)} · Sunset ${tidalTime(set)}',
            style: muted,
          ),
        ],
      ),
    );
  }
}
