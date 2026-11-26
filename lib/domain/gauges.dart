import '../data/gauge_repository.dart';
import '../models/descent.dart';
import '../models/realtime_flow.dart';
import '../models/river_run.dart';
import 'flow_ranges.dart';
import 'flow_status.dart';
import 'run_suggestion.dart' show distanceKm;

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

/// The Gauges tab's three lists. Each gauge appears in one of them only.
typedef GaugeSections = ({
  List<Gauge> starred,
  List<Gauge> recent,
  List<Gauge> all,
});

/// Splits [gauges] into the ones the paddler starred, the ones they've
/// logged a run on (and not starred), and the rest. Each list is in
/// [sortGauges] order.
GaugeSections gaugeSections(
  List<Gauge> gauges, {
  Set<String> favouriteRunIds = const {},
  List<Descent> descents = const [],
  Map<String, StationSummary> stations = const {},
  ({double latitude, double longitude})? position,
  DateTime? now,
}) {
  final logged = {for (final d in descents) d.runId};
  final starred = <Gauge>[], recent = <Gauge>[], all = <Gauge>[];
  for (final g in gauges) {
    if (g.runs.any((r) => favouriteRunIds.contains(r.riverId))) {
      starred.add(g);
    } else if (g.runs.any((r) => logged.contains(r.riverId))) {
      recent.add(g);
    } else {
      all.add(g);
    }
  }
  List<Gauge> sorted(List<Gauge> list) =>
      sortGauges(list, stations: stations, position: position, now: now);
  return (starred: sorted(starred), recent: sorted(recent), all: sorted(all));
}

/// Gauges with a run that's in range right now first, then the nearest to
/// [position] (when the device location is known), then by name.
List<Gauge> sortGauges(
  List<Gauge> gauges, {
  Map<String, StationSummary> stations = const {},
  ({double latitude, double longitude})? position,
  DateTime? now,
}) {
  final keyed = [
    for (final g in gauges)
      (
        gauge: g,
        running: gaugeStatus(g, stations[g.id], now: now).isRunnable,
        km: position == null ? null : gaugeDistanceKm(g, position),
      ),
  ];
  keyed.sort((a, b) {
    if (a.running != b.running) return a.running ? -1 : 1;
    final ka = a.km, kb = b.km;
    if (ka != null && kb != null && ka != kb) return ka.compareTo(kb);
    if (ka != null && kb == null) return -1;
    if (ka == null && kb != null) return 1;
    return a.gauge.title.toLowerCase().compareTo(b.gauge.title.toLowerCase());
  });
  return [for (final k in keyed) k.gauge];
}

/// Readings older than this aren't trusted to say a run is in.
const statusFreshFor = Duration(hours: 24);

/// The best status among the runs on [gauge] at its latest reading, or
/// unknown when there's no reading from the last day.
FlowStatus gaugeStatus(Gauge gauge, StationSummary? summary, {DateTime? now}) {
  if (summary == null) return FlowStatus.unknown;
  final at = summary.readingTime;
  if (at != null && (now ?? DateTime.now()).difference(at) > statusFreshFor) {
    return FlowStatus.unknown;
  }
  return FlowStatus.best(
    gauge.runs.map((r) => r.flowStatus(summary.flow, level: summary.level)),
  );
}

/// Kilometres from [position] to the closest run on [gauge], measured to
/// each run's put-in (or its pin, or its take-out). Null when no run has a
/// location.
double? gaugeDistanceKm(
  Gauge gauge,
  ({double latitude, double longitude}) position,
) {
  double? nearest;
  for (final run in gauge.runs) {
    final at = [run.putInCoordinates, run.coordinates, run.takeOutCoordinates]
        .firstWhere(
          (c) => c?['latitude'] != null && c?['longitude'] != null,
          orElse: () => null,
        );
    if (at == null) continue;
    final km = distanceKm(
      position.latitude,
      position.longitude,
      at['latitude']!,
      at['longitude']!,
    );
    if (nearest == null || km < nearest) nearest = km;
  }
  return nearest;
}

/// "800 m away", "12 km away".
String distanceLabel(double km) {
  if (km < 1) return 'Under 1 km away';
  if (km < 10) return '${km.toStringAsFixed(1)} km away';
  return '${km.round()} km away';
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

/// "Low 25 · Medium 50 · High 100 m³/s", or null when the run has none.
String? rangeSummary(RiverRun run) => run.ranges?.summary;

/// The unit a gauge page leads with: metres when most of its runs with
/// flows are read on the stick (the Cheakamus, the Chilliwack), else m³/s.
FlowUnit gaugeUnit(Iterable<RiverRun> runs) {
  var metres = 0, cms = 0;
  for (final run in runs) {
    final r = run.ranges;
    if (r == null || !r.readOnGaugeOf(run)) continue;
    r.unit == FlowUnit.metres ? metres++ : cms++;
  }
  return metres > cms ? FlowUnit.metres : FlowUnit.cms;
}

/// Readings with a value in [unit], oldest first.
List<FlowReading> readingsIn(List<FlowReading> readings, FlowUnit unit) =>
    unit == FlowUnit.metres
    ? readings.where((r) => r.level != null).toList()
    : dischargeReadings(readings);

/// A reading's value in [unit].
double? valueIn(FlowReading r, FlowUnit unit) =>
    unit == FlowUnit.metres ? r.level : r.discharge;

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

/// Hourly readings within [days] of the latest one, as discharge or, for
/// [FlowUnit.metres], water level.
List<FlowPoint> hourlyWindow(
  List<FlowReading> readings,
  int days, {
  FlowUnit unit = FlowUnit.cms,
}) {
  final flows = readingsIn(readings, unit);
  if (flows.isEmpty) return const [];
  final from = flows.last.timestamp.subtract(Duration(days: days));
  return [
    for (final r in flows)
      if (!r.timestamp.isBefore(from))
        (time: r.timestamp, flow: valueIn(r, unit)!),
  ];
}

/// Daily means from `station_data` year documents' `daily_readings` maps,
/// between [from] and [to], oldest first.
List<FlowPoint> dailySeries(
  Iterable<Map<String, dynamic>> dailyReadings,
  DateTime from,
  DateTime to, {
  FlowUnit unit = FlowUnit.cms,
}) {
  final field = unit == FlowUnit.metres ? 'mean_level' : 'mean_discharge';
  final points = <FlowPoint>[];
  for (final daily in dailyReadings) {
    daily.forEach((key, value) {
      final day = DateTime.tryParse(key);
      final mean = value is Map ? value[field] : null;
      if (day == null || mean is! num) return;
      if (day.isBefore(from) || day.isAfter(to)) return;
      points.add((time: day, flow: mean.toDouble()));
    });
  }
  points.sort((a, b) => a.time.compareTo(b.time));
  return points;
}

/// The runs to favourite for a new paddler, so the Gauges tab opens on
/// local gauges rather than an empty "Your gauges". Which runs is set in
/// the backend: `starter: true` on the run.
Set<String> starterFavouriteRunIds(Iterable<RiverRun> runs) => {
  for (final run in runs)
    if (run.starter) run.riverId,
};
