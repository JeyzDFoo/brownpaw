import '../data/gauge_repository.dart';
import '../models/river_run.dart';
import 'flow_status.dart';

/// One run as the Guide shows it: where it is and how it's running now.
class GuideEntry {
  const GuideEntry({
    required this.run,
    required this.status,
    this.flow,
    this.latitude,
    this.longitude,
  });

  final RiverRun run;

  /// Latest flow at the run's gauge, if it has one and it's reporting.
  final double? flow;

  final FlowStatus status;

  /// Where to put the run's pin: the put-in, else the run's own
  /// coordinates, else the take-out.
  final double? latitude;
  final double? longitude;

  bool get onMap => latitude != null && longitude != null;

  bool matches(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return run.name.toLowerCase().contains(q) ||
        run.river.toLowerCase().contains(q) ||
        (run.region?.toLowerCase().contains(q) ?? false) ||
        run.difficultyClass.toLowerCase().contains(q);
  }
}

/// Builds the Guide's entries from the visible runs and the latest station
/// summaries (keyed by `station_current` id). Running runs come first, then
/// the rest, each group by river and run name.
List<GuideEntry> guideEntries(
  List<RiverRun> runs,
  Map<String, StationSummary> stations,
) {
  final entries = [for (final run in runs) _entryFor(run, stations)];
  int rank(GuideEntry e) => e.status.isRunnable ? 0 : 1;
  entries.sort((a, b) {
    final byRank = rank(a).compareTo(rank(b));
    if (byRank != 0) return byRank;
    final byRiver = a.run.river.toLowerCase().compareTo(
      b.run.river.toLowerCase(),
    );
    if (byRiver != 0) return byRiver;
    return a.run.name.toLowerCase().compareTo(b.run.name.toLowerCase());
  });
  return entries;
}

GuideEntry _entryFor(RiverRun run, Map<String, StationSummary> stations) {
  final station = run.stationId;
  final flow = (station == null || station.isEmpty)
      ? null
      : stations[GaugeRepository.docIdFor(station)]?.flow;
  final at = [
    run.putInCoordinates,
    run.coordinates,
    run.takeOutCoordinates,
  ].firstWhere(_hasPoint, orElse: () => null);
  return GuideEntry(
    run: run,
    flow: flow,
    status: run.flowStatus(flow),
    latitude: at?['latitude'],
    longitude: at?['longitude'],
  );
}

bool _hasPoint(Map<String, double>? c) =>
    c?['latitude'] != null && c?['longitude'] != null;

/// Where the Guide map opens: BC's Lower Mainland, from Vancouver to Hope
/// and up to Squamish.
const lowerMainlandCentre = (latitude: 49.45, longitude: -122.55);
const lowerMainlandZoom = 8.4;

/// The best status among [entries], so a cluster of pins with anything
/// running shows as running.
FlowStatus bestStatus(Iterable<GuideEntry> entries) {
  const order = [
    FlowStatus.good,
    FlowStatus.runnable,
    FlowStatus.tooHigh,
    FlowStatus.tooLow,
    FlowStatus.unknown,
  ];
  return order.firstWhere(
    (s) => entries.any((e) => e.status == s),
    orElse: () => FlowStatus.unknown,
  );
}

/// From this zoom in, every run gets its own pin.
const clusterUntilZoom = 12;
