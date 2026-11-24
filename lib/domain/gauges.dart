import '../data/gauge_repository.dart';
import '../models/descent.dart';
import '../models/realtime_flow.dart';
import '../models/river_run.dart';

/// One gauge station and the runs judged against it.
class Gauge {
  const Gauge({
    required this.id,
    required this.river,
    required this.place,
    required this.runs,
  });

  /// The `station_current` document id, e.g. `environment_canada_08MH001`.
  final String id;

  /// "Chilliwack River".
  final String river;

  /// "at Vedder Crossing", or empty when unknown.
  final String place;

  final List<RiverRun> runs;

  /// The station id as stored on runs, for repository calls.
  String get stationId => runs.first.stationId!;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return river.toLowerCase().contains(q) ||
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
/// are left out. Gauges come back sorted by river name.
List<Gauge> gaugesFromRuns(List<RiverRun> runs) {
  final byId = <String, List<RiverRun>>{};
  for (final run in runs) {
    final station = run.stationId;
    if (station == null || station.isEmpty) continue;
    byId.putIfAbsent(GaugeRepository.docIdFor(station), () => []).add(run);
  }
  final gauges = [
    for (final MapEntry(key: id, value: runs) in byId.entries)
      _gaugeFor(id, runs),
  ]..sort((a, b) => a.river.compareTo(b.river));
  return gauges;
}

Gauge _gaugeFor(String id, List<RiverRun> runs) {
  runs.sort((a, b) => a.name.compareTo(b.name));
  final name = runs
      .map((r) => r.gaugeStation?['name'])
      .firstWhere((n) => n != null && isStationName(n), orElse: () => null);
  if (name != null) {
    final (river, place) = splitStationName(name);
    return Gauge(id: id, river: river, place: place, runs: runs);
  }
  // No usable station name: name it after the river, and list the runs
  // so paddlers can still tell which gauge it is.
  final river = runs.first.river.trim();
  final hasKind = RegExp(
    r'\b(river|creek|canyon|lake)\b',
    caseSensitive: false,
  ).hasMatch(river);
  final runNames = {for (final r in runs) r.name.trim()}
    ..removeWhere((n) => n.isEmpty || n == river);
  return Gauge(
    id: id,
    river: hasKind ? river : '$river River',
    place: runNames.join(' · '),
    runs: runs,
  );
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

/// "CHILLIWACK RIVER AT VEDDER CROSSING" → ("Chilliwack River",
/// "at Vedder Crossing"). Names without "at", "near", "above" or "below"
/// come back whole.
(String, String) splitStationName(String raw) {
  final name = raw.trim() == raw.trim().toUpperCase()
      ? _titleCase(raw.trim())
      : raw.trim();
  final match = RegExp(
    r'^(.*?)\s+(at|near|above|below)\s+(.*)$',
    caseSensitive: false,
  ).firstMatch(name);
  if (match == null) return (name, '');
  return (match[1]!, '${match[2]!.toLowerCase()} ${match[3]!}');
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
    return a.river.compareTo(b.river);
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
