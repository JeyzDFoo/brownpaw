import 'package:intl/intl.dart';

/// Dam-release gauges: rivers whose flow is set by a dam's published
/// schedule rather than read off a live gauge. So far TransAlta's Barrier
/// and Pocaterra plants on the Kananaskis (functions/transalta.py).
///
/// The Cloud Function stores the schedule on `station_current/{id}` as
/// `release_schedule_csv`: `start,flow`, one row per hour in UTC, from the
/// start of today (Alberta time) to the end of what's published.

/// Whether the gauge with `station_current` id [id] is a dam release.
bool isReleaseGauge(String id) => id.startsWith('transalta_');

/// The wall-clock offset the schedule is published in: Alberta, on
/// permanent UTC-6 since November 2026. Times are shown in river time,
/// the same as the signs at the put-in, wherever the paddler's phone is.
const releaseUtcOffset = Duration(hours: -6);

/// [t] as Alberta wall time, in a UTC DateTime whose fields read as
/// Alberta's clock (Dart has no fixed-offset DateTime).
DateTime riverWall(DateTime t) => t.toUtc().add(releaseUtcOffset);

/// One hour of the schedule.
typedef ReleaseHour = ({DateTime start, double flow});

/// A stretch of consecutive hours with the dam releasing.
class ReleaseWindow {
  const ReleaseWindow({
    required this.start,
    required this.end,
    required this.minFlow,
    required this.maxFlow,
  });

  /// UTC instants.
  final DateTime start;
  final DateTime end;
  final double minFlow;
  final double maxFlow;

  /// The flow to judge the run on: the window's peak.
  double get flow => maxFlow;

  bool contains(DateTime t) => !t.isBefore(start) && t.isBefore(end);

  /// "28" or "21–28" m³/s.
  String get flowText =>
      minFlow == maxFlow ? _n(maxFlow) : '${_n(minFlow)}–${_n(maxFlow)}';

  /// "5 PM–11 PM".
  String get timeText => '${hourLabel(start)}–${hourLabel(end)}';

  @override
  String toString() => 'ReleaseWindow($start–$end, $flowText)';
}

String _n(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// "5 PM", "11 AM", "Midnight", "Noon", in river time.
String hourLabel(DateTime t) {
  final w = riverWall(t);
  if (w.minute == 0 && w.hour == 0) return 'Midnight';
  if (w.minute == 0 && w.hour == 12) return 'Noon';
  return DateFormat(w.minute == 0 ? 'h a' : 'h:mm a').format(w);
}

/// "Today", "Tomorrow", "Sun, Nov 29", in river time.
String dayLabel(DateTime day, DateTime now) {
  final d = riverWall(day), n = riverWall(now);
  final a = DateTime.utc(d.year, d.month, d.day);
  final b = DateTime.utc(n.year, n.month, n.day);
  final diff = a.difference(b).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return DateFormat('EEE, MMM d').format(d);
}

/// One river-time day of the schedule.
class ReleaseDay {
  const ReleaseDay({required this.start, required this.hours});

  /// Midnight river time, as a UTC instant.
  final DateTime start;

  /// The day's published hours, oldest first (up to 24).
  final List<ReleaseHour> hours;

  DateTime get end => start.add(const Duration(days: 1));

  /// Release windows within the day, cut at midnight.
  List<ReleaseWindow> get windows => releaseWindows(hours);
}

/// A dam's published release schedule.
class ReleaseSchedule {
  ReleaseSchedule(List<ReleaseHour> hours)
    : hours = List.unmodifiable(
        [...hours]..sort((a, b) => a.start.compareTo(b.start)),
      );

  /// From a stored `release_schedule_csv`: `start,flow` rows.
  factory ReleaseSchedule.fromCsv(String csv) {
    final hours = <ReleaseHour>[];
    for (final line in csv.split('\n').skip(1)) {
      final parts = line.trim().split(',');
      if (parts.length < 2) continue;
      final start = DateTime.tryParse(parts[0]);
      final flow = double.tryParse(parts[1]);
      if (start == null || flow == null || !flow.isFinite) continue;
      hours.add((start: start.toUtc(), flow: flow));
    }
    return ReleaseSchedule(hours);
  }

  final List<ReleaseHour> hours;

  bool get isEmpty => hours.isEmpty;

  /// When the published schedule runs out.
  DateTime? get publishedUntil =>
      hours.isEmpty ? null : hours.last.start.add(const Duration(hours: 1));

  /// Every release window, merging hours across midnight.
  List<ReleaseWindow> get windows => releaseWindows(hours);

  /// The scheduled flow at [now], or null outside the published hours.
  double? flowAt(DateTime now) {
    for (final h in hours) {
      if (!now.isBefore(h.start) &&
          now.isBefore(h.start.add(const Duration(hours: 1)))) {
        return h.flow;
      }
    }
    return null;
  }

  /// The window the dam is releasing in at [now], if any.
  ReleaseWindow? current(DateTime now) {
    for (final w in windows) {
      if (w.contains(now)) return w;
    }
    return null;
  }

  /// The next window starting after [now].
  ReleaseWindow? next(DateTime now) {
    for (final w in windows) {
      if (w.start.isAfter(now)) return w;
    }
    return null;
  }

  /// The published hours split into river-time days, from today on.
  List<ReleaseDay> days(DateTime now) {
    final byDay = <DateTime, List<ReleaseHour>>{};
    for (final h in hours) {
      final w = riverWall(h.start);
      final midnight = DateTime.utc(
        w.year,
        w.month,
        w.day,
      ).subtract(releaseUtcOffset);
      byDay.putIfAbsent(midnight, () => []).add(h);
    }
    final today = riverWall(now);
    final todayStart = DateTime.utc(
      today.year,
      today.month,
      today.day,
    ).subtract(releaseUtcOffset);
    final keys = byDay.keys.where((d) => !d.isBefore(todayStart)).toList()
      ..sort();
    return [for (final d in keys) ReleaseDay(start: d, hours: byDay[d]!)];
  }
}

/// Consecutive hours with flow above zero, merged.
List<ReleaseWindow> releaseWindows(List<ReleaseHour> hours) {
  final out = <ReleaseWindow>[];
  DateTime? start, end;
  double lo = 0, hi = 0;
  void close() {
    if (start != null) {
      out.add(
        ReleaseWindow(start: start!, end: end!, minFlow: lo, maxFlow: hi),
      );
    }
    start = null;
  }

  for (final h in hours) {
    final hourEnd = h.start.add(const Duration(hours: 1));
    if (h.flow <= 0) {
      close();
      continue;
    }
    if (start != null && h.start == end) {
      end = hourEnd;
      if (h.flow < lo) lo = h.flow;
      if (h.flow > hi) hi = h.flow;
    } else {
      close();
      start = h.start;
      end = hourEnd;
      lo = hi = h.flow;
    }
  }
  close();
  return out;
}

/// What a release gauge is doing, in a sentence a paddler can act on.
class ReleaseOutlook {
  const ReleaseOutlook({
    required this.releasing,
    this.window,
    required this.headline,
    required this.detail,
  });

  /// Whether water is coming down now.
  final bool releasing;

  /// The window now, or the next one; null when none is scheduled.
  final ReleaseWindow? window;

  /// "Releasing until 11 PM", "Next release today", "No release scheduled".
  final String headline;

  /// "28 m³/s · 5 PM–11 PM", or how far the schedule reaches.
  final String detail;

  /// The flow to lead with: now's, or the next window's.
  double? get flow => window?.flow;
}

/// The outlook for [schedule] at [now].
ReleaseOutlook releaseOutlook(ReleaseSchedule? schedule, DateTime now) {
  if (schedule == null || schedule.isEmpty) {
    return const ReleaseOutlook(
      releasing: false,
      headline: 'No schedule yet',
      detail: "TransAlta's release times will show here",
    );
  }
  final current = schedule.current(now);
  if (current != null) {
    return ReleaseOutlook(
      releasing: true,
      window: current,
      headline: 'Releasing until ${hourLabel(current.end)}',
      detail: '${current.flowText} m³/s since ${hourLabel(current.start)}',
    );
  }
  final next = schedule.next(now);
  if (next != null) {
    final day = dayLabel(next.start, now);
    return ReleaseOutlook(
      releasing: false,
      window: next,
      headline:
          'Next release ${day == 'Today' || day == 'Tomorrow' ? day.toLowerCase() : day}',
      detail: '${next.flowText} m³/s · ${next.timeText}',
    );
  }
  final until = schedule.publishedUntil!;
  return ReleaseOutlook(
    releasing: false,
    headline: 'No release scheduled',
    detail:
        'Schedule runs to '
        '${dayLabel(until.subtract(const Duration(minutes: 1)), now)}',
  );
}

/// Hourly flows as one point per river-time day: that day's highest
/// release, so a chart of a dam reads as "what it ran at" day by day
/// rather than a comb of on-off hours.
List<({DateTime time, double flow})> dailyReleasePeaks(
  Iterable<({DateTime time, double flow})> hourly,
) {
  final peaks = <DateTime, double>{};
  for (final p in hourly) {
    final w = riverWall(p.time);
    final day = DateTime.utc(w.year, w.month, w.day).subtract(releaseUtcOffset);
    final prev = peaks[day];
    if (prev == null || p.flow > prev) peaks[day] = p.flow;
  }
  final days = peaks.keys.toList()..sort();
  return [for (final d in days) (time: d, flow: peaks[d]!)];
}

/// "Starts in 2 h 20 min", "Ends in 45 min", or null with no window.
String? releaseCountdown(ReleaseOutlook outlook, DateTime now) {
  final w = outlook.window;
  if (w == null) return null;
  final target = outlook.releasing ? w.end : w.start;
  final mins = target.difference(now).inMinutes;
  if (mins < 0) return null;
  // Past a day, the day name in the headline says enough.
  if (!outlook.releasing && mins >= 24 * 60) return null;
  final h = mins ~/ 60, m = mins % 60;
  final span = h == 0
      ? '$m min'
      : m == 0
      ? '$h h'
      : '$h h $m min';
  return outlook.releasing ? 'Ends in $span' : 'Starts in $span';
}
