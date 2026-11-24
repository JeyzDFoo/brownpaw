import '../data/gauge_repository.dart';
import '../models/descent.dart';
import '../models/realtime_flow.dart';
import '../models/river_run.dart';

/// One gauge station and the runs judged against it.
class Gauge {
  const Gauge({
    required this.id,
    required this.title,
    required this.place,
    required this.runs,
  });

  /// The `station_current` document id, e.g. `environment_canada_08MH001`.
  final String id;

  /// The station's official name, "Cheakamus River above Millar Creek",
  /// or the river's name until that's known.
  final String title;

  /// The runs on this gauge, "Paradise Valley · Dam Run".
  final String place;

  final List<RiverRun> runs;

  /// The station id as stored on runs, for repository calls.
  String get stationId => runs.first.stationId!;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return title.toLowerCase().contains(q) ||
        place.toLowerCase().contains(q) ||
        id.toLowerCase().contains(q) ||
        runs.any(
          (r) =>
              r.name.toLowerCase().contains(q) ||
              r.river.toLowerCase().contains(q),
        );
  }
}

/// Groups runs by the station they're read against. Runs with no station
/// are left out. [stationNames] maps `station_current` ids to official
/// names (from the `stations` collection). Gauges come back sorted by title.
List<Gauge> gaugesFromRuns(
  List<RiverRun> runs, {
  Map<String, String> stationNames = const {},
}) {
  final byId = <String, List<RiverRun>>{};
  for (final run in runs) {
    final station = run.stationId;
    if (station == null || station.isEmpty) continue;
    byId.putIfAbsent(GaugeRepository.docIdFor(station), () => []).add(run);
  }
  final gauges = [
    for (final MapEntry(key: id, value: runs) in byId.entries)
      _gaugeFor(id, runs, stationNames[id]),
  ]..sort((a, b) => a.title.compareTo(b.title));
  return gauges;
}

Gauge _gaugeFor(String id, List<RiverRun> runs, String? official) {
  runs.sort((a, b) => a.name.compareTo(b.name));
  final imported = runs
      .map((r) => r.gaugeStation?['name'])
      .firstWhere((n) => n != null && isStationName(n), orElse: () => null);
  final name = (official != null && isStationName(official))
      ? official
      : imported;
  final title = name != null ? stationTitle(name) : _riverTitle(runs.first);
  final labels = <String>{for (final r in runs) runLabel(r)}
    ..removeWhere((n) => n.isEmpty || n == title);
  return Gauge(id: id, title: title, place: labels.join(' · '), runs: runs);
}

/// The river's name, for a gauge whose station name isn't known yet.
/// Some imported runs repeat the run in the river field
/// ("Clearwater River - Gatling Gorge") or start with stray punctuation.
String _riverTitle(RiverRun run) {
  var river = run.river
      .split(RegExp(r' [-–] '))
      .first
      .replaceFirst(RegExp(r'^[^A-Za-z]+'), '')
      .trim();
  if (river.isEmpty) river = run.name.trim();
  final hasKind = RegExp(
    r'\b(river|creek|canyon|lake)\b',
    caseSensitive: false,
  ).hasMatch(river);
  return hasKind ? river : '$river River';
}

/// A run's name without the river in front: "Clearwater River - Upper"
/// → "Upper", for places where the river is already shown.
String runLabel(RiverRun run) {
  final name = run.name.trim();
  final match = RegExp(r' [-–] ').firstMatch(name);
  if (match == null || match.start == 0) return name;
  final rest = name.substring(match.end).trim();
  return rest.isEmpty ? name : rest;
}

/// Who publishes the readings for the gauge with `station_current` id
/// [id], credited under the latest reading.
String gaugeSource(String id) {
  if (id.startsWith('metro_vancouver_')) return 'Metro Vancouver';
  if (id.startsWith('flowworks_')) return 'District of North Vancouver';
  if (id.startsWith('environment_canada_')) return 'Environment Canada';
  return '';
}

/// Whether [name] reads like a station name rather than a stray reading
/// such as "96.4cms↓" or "1.875m↓" (the BC Whitewater import stored some
/// of those in `gaugeStation.name`).
bool isStationName(String name) {
  final n = name.trim();
  if (n.isEmpty) return false;
  if (RegExp(r'^[\d.,]').hasMatch(n)) return false;
  if (RegExp(r'[↑↓]').hasMatch(n)) return false;
  return RegExp(r'[A-Za-z]{3,}').hasMatch(n);
}

/// Environment Canada names are upper case:
/// "CHEAKAMUS RIVER ABOVE MILLAR CREEK" → "Cheakamus River above Millar
/// Creek". Names already in mixed case are kept.
String stationTitle(String raw) {
  final name = raw.trim();
  return name == name.toUpperCase() ? _titleCase(name) : name;
}

String _titleCase(String s) {
  const small = {'at', 'near', 'above', 'below', 'of', 'the', 'and'};
  final words = s.toLowerCase().split(RegExp(r'\s+'));
  return [
    for (var i = 0; i < words.length; i++)
      if (i > 0 && small.contains(words[i]))
        words[i]
      else if (words[i].isEmpty)
        words[i]
      else
        words[i][0].toUpperCase() + words[i].substring(1),
  ].join(' ');
}

/// The gauges a paddler cares about: those for runs they've favourited or
/// logged, most recently logged first, then favourites by name.
List<Gauge> yourGauges(
  List<Gauge> gauges, {
  Set<String> favouriteRunIds = const {},
  List<Descent> descents = const [],
}) {
  final lastLogged = <String, DateTime>{};
  for (final d in descents) {
    final prev = lastLogged[d.runId];
    if (prev == null || d.date.isAfter(prev)) lastLogged[d.runId] = d.date;
  }
  DateTime? latestFor(Gauge g) {
    DateTime? latest;
    for (final r in g.runs) {
      final t = lastLogged[r.riverId];
      if (t != null && (latest == null || t.isAfter(latest))) latest = t;
    }
    return latest;
  }

  final mine = gauges
      .where(
        (g) => g.runs.any(
          (r) =>
              favouriteRunIds.contains(r.riverId) ||
              lastLogged.containsKey(r.riverId),
        ),
      )
      .toList();
  mine.sort((a, b) {
    final ta = latestFor(a), tb = latestFor(b);
    if (ta != null && tb != null) return tb.compareTo(ta);
    if (ta != null) return -1;
    if (tb != null) return 1;
    return a.title.compareTo(b.title);
  });
  return mine;
}

enum GaugeTrend {
  rising('Rising'),
  steady('Steady'),
  falling('Falling');

  const GaugeTrend(this.label);
  final String label;
}

/// Flow readings with a discharge, oldest first.
List<FlowReading> dischargeReadings(List<FlowReading> readings) =>
    readings.where((r) => r.discharge != null).toList();

/// Rising or falling when flow moved more than 3% over the last [window];
/// steady otherwise. Null with fewer than two readings.
GaugeTrend? trendOf(
  List<FlowReading> readings, {
  Duration window = const Duration(hours: 3),
}) {
  final flows = dischargeReadings(readings);
  if (flows.length < 2) return null;
  final latest = flows.last;
  final cutoff = latest.timestamp.subtract(window);
  final earlier = flows.lastWhere(
    (r) => !r.timestamp.isAfter(cutoff),
    orElse: () => flows.first,
  );
  if (identical(earlier, latest)) return null;
  final from = earlier.discharge!, to = latest.discharge!;
  final change = from == 0 ? to : (to - from) / from;
  if (change > 0.03) return GaugeTrend.rising;
  if (change < -0.03) return GaugeTrend.falling;
  return GaugeTrend.steady;
}

/// "Updated 14 min ago", "Updated 3 h ago", "Updated Nov 2".
String updatedAgo(DateTime timestamp, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(timestamp);
  if (diff.inMinutes < 1) return 'Updated just now';
  if (diff.inMinutes < 60) return 'Updated ${diff.inMinutes} min ago';
  if (diff.inHours < 24) return 'Updated ${diff.inHours} h ago';
  if (diff.inDays == 1) return 'Updated yesterday';
  return 'Updated ${diff.inDays} days ago';
}

/// Readings older than this are flagged in the app: the gauges update
/// every few hours, and Environment Canada lags an hour or two behind.
const staleAfter = Duration(hours: 6);

/// Whether a reading from [timestamp] is old enough to warn about.
bool isStale(DateTime timestamp, {DateTime? now}) =>
    (now ?? DateTime.now()).difference(timestamp) > staleAfter;

/// "good at 20 to 40", or the runnable range when that's all there is.
String? goodRange(RiverRun run) {
  String n(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';
  if (run.optimalFlowMin != null && run.optimalFlowMax != null) {
    return 'good at ${n(run.optimalFlowMin!)} to ${n(run.optimalFlowMax!)}';
  }
  if (run.minRecommendedFlow != null && run.maxRecommendedFlow != null) {
    return 'runs at ${n(run.minRecommendedFlow!)} to '
        '${n(run.maxRecommendedFlow!)}';
  }
  return null;
}

/// A flow at a moment, for charts.
typedef FlowPoint = ({DateTime time, double flow});

/// How far back the gauge chart reaches. Hourly readings cover the last
/// month; longer spans use daily means.
enum GaugeSpan {
  twoDays('2D', '2 days', 2),
  twoWeeks('2W', '2 weeks', 14),
  oneMonth('1M', '1 month', 30),
  sixMonths('6M', '6 months', 182),
  oneYear('1Y', '1 year', 365);

  const GaugeSpan(this.short, this.label, this.days);
  final String short;
  final String label;
  final int days;

  bool get usesDaily => days > 30;
}

/// Hourly readings within [days] of the latest one.
List<FlowPoint> hourlyWindow(List<FlowReading> readings, int days) {
  final flows = dischargeReadings(readings);
  if (flows.isEmpty) return const [];
  final from = flows.last.timestamp.subtract(Duration(days: days));
  return [
    for (final r in flows)
      if (!r.timestamp.isBefore(from)) (time: r.timestamp, flow: r.discharge!),
  ];
}

/// Daily means from `station_data` year documents' `daily_readings` maps,
/// between [from] and [to], oldest first.
List<FlowPoint> dailySeries(
  Iterable<Map<String, dynamic>> dailyReadings,
  DateTime from,
  DateTime to,
) {
  final points = <FlowPoint>[];
  for (final daily in dailyReadings) {
    daily.forEach((key, value) {
      final day = DateTime.tryParse(key);
      final mean = value is Map ? value['mean_discharge'] : null;
      if (day == null || mean is! num) return;
      if (day.isBefore(from) || day.isAfter(to)) return;
      points.add((time: day, flow: mean.toDouble()));
    });
  }
  points.sort((a, b) => a.time.compareTo(b.time));
  return points;
}
