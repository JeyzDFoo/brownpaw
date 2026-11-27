import 'dart:math' as math;

import 'package:intl/intl.dart';

/// Tidal play spots: waves made by tidal current rather than river flow.
/// So far Skookumchuck Narrows, read on the Sechelt Rapids predictions
/// (functions/tidal.py).
///
/// The Cloud Function stores `current_events_csv` (`time,kind,knots`, kind
/// slack / flood / ebb, UTC) and `tide_events_csv` (`time,kind,metres`,
/// kind high / low) on `station_current/{id}`.

/// Whether the gauge with `station_current` id [id] is a tidal spot.
bool isTidalGauge(String id) => id.startsWith('tidal_');

/// BC's wall clock: permanent UTC-7 since November 2026. Times show in
/// the spot's own time wherever the paddler's phone is.
const tidalUtcOffset = Duration(hours: -7);

/// [t] as BC wall time, in a UTC DateTime whose fields read as BC's clock.
DateTime tidalWall(DateTime t) => t.toUtc().add(tidalUtcOffset);

/// Midnight BC time for the day holding [t], as a UTC instant.
DateTime tidalDayStart(DateTime t) {
  final w = tidalWall(t);
  return DateTime.utc(w.year, w.month, w.day).subtract(tidalUtcOffset);
}

/// "8:59 AM", in BC time.
String tidalTime(DateTime t) => DateFormat('h:mm a').format(tidalWall(t));

/// "9a", "12:30p": to the nearest half hour, short enough for a calendar
/// cell.
String tidalShortTime(DateTime t) {
  final w = tidalWall(t);
  final q = ((w.hour * 60 + w.minute + 15) ~/ 30) * 30 % (24 * 60);
  final h = q ~/ 60;
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$h12${q % 60 == 30 ? ':30' : ''}${h < 12 ? 'a' : 'p'}';
}

/// "Today", "Tomorrow", "Sun, Nov 29", in BC time.
String tidalDayLabel(DateTime day, DateTime now) {
  final diff = tidalDayStart(day).difference(tidalDayStart(now)).inHours ~/ 24;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  return DateFormat('EEE, MMM d').format(tidalWall(day));
}

/// "14.2".
String knotsText(double v) => v.toStringAsFixed(1);

enum CurrentKind { slack, flood, ebb }

/// A turning point of the current: slack water, or a max flood or ebb.
class CurrentEvent {
  const CurrentEvent(this.time, this.kind, this.knots);

  final DateTime time;
  final CurrentKind kind;

  /// Unsigned speed; 0 at slack.
  final double knots;

  /// Flood positive, ebb negative.
  double get signed => kind == CurrentKind.ebb ? -knots : knots;

  bool get isFlood => kind == CurrentKind.flood;
  bool get isEbb => kind == CurrentKind.ebb;
  bool get isSlack => kind == CurrentKind.slack;

  @override
  String toString() => 'CurrentEvent($time, ${kind.name}, $knots)';
}

/// A high or low tide.
class TideEvent {
  const TideEvent(this.time, this.high, this.metres);
  final DateTime time;
  final bool high;
  final double metres;
}

/// One flood: the slack it starts from, its peak, and the slack it ends
/// at, with the ebb before it (Skook paddlers look for an ebb close to the
/// flood's size).
class Flood {
  const Flood({required this.max, this.start, this.end, this.ebbBefore});

  final CurrentEvent max;

  /// Slack before and after, when known.
  final DateTime? start;
  final DateTime? end;
  final CurrentEvent? ebbBefore;

  DateTime get time => max.time;
  double get knots => max.knots;

  bool contains(DateTime t) =>
      start != null && end != null && !t.isBefore(start!) && t.isBefore(end!);
}

/// Predicted currents and tides for one tidal spot.
class TidalPredictions {
  TidalPredictions({
    required List<CurrentEvent> currents,
    List<TideEvent> tides = const [],
    this.source,
    this.tideStation,
  }) : currents = List.unmodifiable(
         [...currents]..sort((a, b) => a.time.compareTo(b.time)),
       ),
       tides = List.unmodifiable(
         [...tides]..sort((a, b) => a.time.compareTo(b.time)),
       );

  /// From a stored `station_current` document's fields.
  factory TidalPredictions.fromDoc(Map<String, dynamic> data) {
    final currents = <CurrentEvent>[];
    for (final row in _rows(data['current_events_csv'])) {
      final kind = switch (row.$2) {
        'flood' => CurrentKind.flood,
        'ebb' => CurrentKind.ebb,
        'slack' => CurrentKind.slack,
        _ => null,
      };
      if (kind != null) currents.add(CurrentEvent(row.$1, kind, row.$3));
    }
    final tides = [
      for (final row in _rows(data['tide_events_csv']))
        TideEvent(row.$1, row.$2 == 'high', row.$3),
    ];
    final source = data['current_source'];
    final station = data['tide_station'];
    return TidalPredictions(
      currents: currents,
      tides: tides,
      source: source is String ? source : null,
      tideStation: station is String ? station : null,
    );
  }

  final List<CurrentEvent> currents;
  final List<TideEvent> tides;

  /// 'dairiki' or 'chs'.
  final String? source;

  /// Where the tide heights are predicted: "Egmont".
  final String? tideStation;

  bool get isEmpty => currents.isEmpty;

  /// Who the current predictions are from, for a credit line.
  String get sourceName => switch (source) {
    'chs' => 'Canadian Hydrographic Service',
    _ => 'dairiki.org (XTide)',
  };

  DateTime? get first => currents.isEmpty ? null : currents.first.time;
  DateTime? get last => currents.isEmpty ? null : currents.last.time;

  /// The predicted current at [t] in knots, flood positive. Between turning
  /// points the speed follows a half cosine, the usual shape of a tidal
  /// current; null outside the predictions.
  double? speedAt(DateTime t) =>
      _interp([for (final e in currents) (e.time, e.signed)], t);

  /// The predicted tide height at [t], metres above chart datum.
  double? tideAt(DateTime t) =>
      _interp([for (final e in tides) (e.time, e.metres)], t);

  /// Every flood, with its slacks and the ebb before it.
  late final List<Flood> floods = () {
    final out = <Flood>[];
    for (var i = 0; i < currents.length; i++) {
      final e = currents[i];
      if (!e.isFlood) continue;
      DateTime? start, end;
      CurrentEvent? ebb;
      for (var j = i - 1; j >= 0; j--) {
        final p = currents[j];
        if (p.isSlack && start == null) start = p.time;
        if (p.isEbb) {
          ebb = p;
          break;
        }
        if (p.isFlood) break;
      }
      for (var j = i + 1; j < currents.length; j++) {
        final n = currents[j];
        if (n.isSlack) {
          end = n.time;
          break;
        }
        if (!n.isSlack) break;
      }
      out.add(Flood(max: e, start: start, end: end, ebbBefore: ebb));
    }
    return out;
  }();

  /// The flood running at [now], or the next one to come.
  Flood? floodNowOrNext(DateTime now) {
    for (final f in floods) {
      if (f.contains(now)) return f;
      if (f.end == null && f.time.isAfter(now)) return f;
      if (f.start != null && f.start!.isAfter(now)) return f;
      if (f.start == null && f.time.isAfter(now)) return f;
    }
    return null;
  }

  /// The next flood peaking after [now] in daylight at [lat], [lon].
  Flood? nextDaylightFlood(DateTime now, double lat, double lon) {
    for (final f in floods) {
      if (f.time.isAfter(now) && isDaylight(f.time, lat, lon)) return f;
    }
    return null;
  }

  /// The slacks after [now], soonest first.
  Iterable<CurrentEvent> slacksAfter(DateTime now) =>
      currents.where((e) => e.isSlack && e.time.isAfter(now));

  /// Floods peaking on the BC day starting at [dayStart].
  List<Flood> floodsOn(DateTime dayStart) {
    final end = dayStart.add(const Duration(days: 1));
    return [
      for (final f in floods)
        if (!f.time.isBefore(dayStart) && f.time.isBefore(end)) f,
    ];
  }

  /// Current events on the BC day starting at [dayStart].
  List<CurrentEvent> currentsOn(DateTime dayStart) {
    final end = dayStart.add(const Duration(days: 1));
    return [
      for (final e in currents)
        if (!e.time.isBefore(dayStart) && e.time.isBefore(end)) e,
    ];
  }

  /// Tides on the BC day starting at [dayStart].
  List<TideEvent> tidesOn(DateTime dayStart) {
    final end = dayStart.add(const Duration(days: 1));
    return [
      for (final e in tides)
        if (!e.time.isBefore(dayStart) && e.time.isBefore(end)) e,
    ];
  }

  /// The day's biggest flood in daylight, the one a paddler would drive
  /// for; null when every flood that day peaks in the dark.
  Flood? bestDaylightFlood(DateTime dayStart, double lat, double lon) {
    Flood? best;
    for (final f in floodsOn(dayStart)) {
      if (!isDaylight(f.time, lat, lon)) continue;
      if (best == null || f.knots > best.knots) best = f;
    }
    return best;
  }

  /// BC days covered by the predictions, from [from]'s day on.
  List<DateTime> days({DateTime? from}) {
    final a = first, b = last;
    if (a == null || b == null) return const [];
    var d = tidalDayStart(from != null && from.isAfter(a) ? from : a);
    final out = <DateTime>[];
    while (!d.isAfter(b)) {
      out.add(d);
      d = d.add(const Duration(days: 1));
    }
    return out;
  }
}

Iterable<(DateTime, String, double)> _rows(Object? csv) sync* {
  if (csv is! String) return;
  for (final line in csv.split('\n').skip(1)) {
    final parts = line.trim().split(',');
    if (parts.length < 3) continue;
    final t = DateTime.tryParse(parts[0]);
    final v = double.tryParse(parts[2]);
    if (t == null || v == null || !v.isFinite) continue;
    yield (t.toUtc(), parts[1], v);
  }
}

/// Half-cosine interpolation through turning points.
double? _interp(List<(DateTime, double)> pts, DateTime t) {
  if (pts.isEmpty) return null;
  if (t.isBefore(pts.first.$1) || t.isAfter(pts.last.$1)) return null;
  for (var i = 0; i < pts.length - 1; i++) {
    final (ta, a) = pts[i];
    final (tb, b) = pts[i + 1];
    if (t.isBefore(ta) || t.isAfter(tb)) continue;
    final span = tb.difference(ta).inSeconds;
    if (span <= 0) return a;
    final f = t.difference(ta).inSeconds / span;
    return a + (b - a) * (1 - math.cos(math.pi * f)) / 2;
  }
  return pts.last.$2;
}

/// What a tidal spot is doing now, in words a paddler can act on.
class TidalOutlook {
  const TidalOutlook({
    required this.headline,
    required this.detail,
    this.flood,
    this.speedNow,
    this.flooding = false,
  });

  /// "Next max flood", "Flooding now", "No predictions yet".
  final String headline;

  /// "Sat 8:59 AM · slack 5:30 AM to 12:46 PM".
  final String detail;

  /// The flood now or next.
  final Flood? flood;

  /// The current now, flood positive.
  final double? speedNow;

  /// Whether the flood is running now.
  final bool flooding;

  /// What runs are judged on: the max of the flood now or next.
  double? get knots => flood?.knots;
}

/// The outlook at [now]. With the spot's [lat] and [lon], a flood that
/// would peak in the dark is passed over for the next one in daylight
/// (unless it's running now): nobody drives to Skook for a night flood.
TidalOutlook tidalOutlook(
  TidalPredictions? p,
  DateTime now, {
  double? lat,
  double? lon,
}) {
  if (p == null || p.isEmpty) {
    return const TidalOutlook(
      headline: 'No predictions yet',
      detail: 'Current predictions will show here',
    );
  }
  var f = p.floodNowOrNext(now);
  if (f != null &&
      lat != null &&
      lon != null &&
      !f.contains(now) &&
      !isDaylight(f.time, lat, lon)) {
    f = p.nextDaylightFlood(now, lat, lon) ?? f;
  }
  final speed = p.speedAt(now);
  if (f == null) {
    return TidalOutlook(
      headline: 'No flood predicted',
      detail: 'Predictions run to ${tidalDayLabel(p.last!, now)}',
      speedNow: speed,
    );
  }
  final flooding = f.contains(now);
  final peaked = !f.time.isAfter(now);
  final day = tidalDayLabel(f.time, now);
  final when = day == 'Today'
      ? tidalTime(f.time)
      : '${day == 'Tomorrow' ? 'Tomorrow' : day} ${tidalTime(f.time)}';
  final window = f.start != null && f.end != null
      ? 'slack ${tidalTime(f.start!)} to ${tidalTime(f.end!)}'
      : null;
  return TidalOutlook(
    headline: flooding
        ? (peaked ? 'Flood easing' : 'Flooding now')
        : 'Next max flood',
    detail: [peaked ? 'Peaked $when' : 'Peaks $when', ?window].join(' · '),
    flood: f,
    speedNow: speed,
    flooding: flooding,
  );
}

/// "Peaks in 2 h 10 min", "Slack in 40 min", or null.
String? tidalCountdown(TidalOutlook o, DateTime now) {
  final f = o.flood;
  if (f == null) return null;
  final (verb, target) = !f.time.isBefore(now)
      ? ('Peaks', f.time)
      : ('Slack', f.end);
  if (target == null) return null;
  final mins = target.difference(now).inMinutes;
  if (mins < 0 || mins >= 24 * 60) return null;
  final h = mins ~/ 60, m = mins % 60;
  final span = h == 0
      ? '$m min'
      : m == 0
      ? '$h h'
      : '$h h $m min';
  return '$verb in $span';
}

/// How the ebb before a flood compares, the Skook paddlers' rule of thumb:
/// an ebb close to the flood's size makes a good wave; a much smaller one
/// usually means a high tide and a weaker wave.
String? ebbNote(Flood f) {
  final e = f.ebbBefore;
  if (e == null || f.knots <= 0) return null;
  final ratio = e.knots / f.knots;
  if (ratio >= 0.75) return 'Ebb before ${knotsText(e.knots)} kt: well matched';
  if (ratio >= 0.5) return 'Ebb before ${knotsText(e.knots)} kt';
  return 'Ebb before only ${knotsText(e.knots)} kt: the wave may be weaker';
}

// --- Sun -------------------------------------------------------------------

/// Sunrise and sunset (UTC) on the BC day starting at [dayStart], from
/// NOAA's simple equation: good to a couple of minutes.
/// [altitude] is the sun's angle at the moment: -0.833° for sunrise and
/// sunset, -6° for civil dawn and dusk (first and last light).
(DateTime, DateTime) sunTimes(
  DateTime dayStart,
  double lat,
  double lon, {
  double altitude = -0.833,
}) {
  final w = tidalWall(dayStart);
  final n = DateTime.utc(
    w.year,
    w.month,
    w.day,
  ).difference(DateTime.utc(2000, 1, 1)).inDays;
  final jstar = n - 0.0008 - lon / 360.0;
  double rad(double d) => d * math.pi / 180;
  final mDeg = (357.5291 + 0.98560028 * jstar) % 360;
  final m = rad(mDeg);
  final c =
      1.9148 * math.sin(m) + 0.02 * math.sin(2 * m) + 0.0003 * math.sin(3 * m);
  final lam = rad((mDeg + c + 180 + 102.9372) % 360);
  final transit =
      2451545.0 + jstar + 0.0053 * math.sin(m) - 0.0069 * math.sin(2 * lam);
  final decl = math.asin(math.sin(lam) * math.sin(rad(23.4397)));
  final phi = rad(lat);
  final cosW =
      (math.sin(rad(altitude)) - math.sin(phi) * math.sin(decl)) /
      (math.cos(phi) * math.cos(decl));
  final wDeg = math.acos(cosW.clamp(-1.0, 1.0)) * 180 / math.pi;
  DateTime at(double jd) => DateTime.utc(
    2000,
    1,
    1,
    12,
  ).add(Duration(seconds: ((jd - 2451545.0) * 86400).round()));
  return (at(transit - wDeg / 360), at(transit + wDeg / 360));
}

/// Whether a flood peaking at [t] can be surfed in the light: between
/// first and last light (civil dawn and dusk), give or take half an hour,
/// since the wave runs for a while either side of the peak.
bool isDaylight(DateTime t, double lat, double lon) {
  final (dawn, dusk) = sunTimes(tidalDayStart(t), lat, lon, altitude: -6);
  const grace = Duration(minutes: 30);
  return !t.isBefore(dawn.subtract(grace)) && !t.isAfter(dusk.add(grace));
}
