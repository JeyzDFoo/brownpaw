import 'dart:math' as math;

import '../models/descent.dart';
import '../models/river_run.dart';

/// Why a run was suggested for a quick log, shown under its name.
enum SuggestionReason {
  nearestPutIn('Nearest put-in to you'),
  lastLogged('Your last logged run'),
  recentlyViewed('Recently viewed');

  const SuggestionReason(this.label);
  final String label;
}

class RunSuggestion {
  const RunSuggestion(this.run, this.reason);
  final RiverRun run;
  final SuggestionReason reason;
}

/// How close (in km) a put-in must be to count as "you're there".
const double nearbyPutInKm = 3;

/// Picks the run a paddler most likely wants to log, in order:
/// 1. A run whose put-in is within [nearbyPutInKm] of [position].
/// 2. The run of their most recent descent.
/// 3. The run they most recently opened.
RunSuggestion? suggestRun({
  required List<RiverRun> runs,
  List<Descent> descents = const [],
  List<String> recentRunIds = const [],
  ({double latitude, double longitude})? position,
}) {
  if (runs.isEmpty) return null;
  final byId = {for (final r in runs) r.riverId: r};

  if (position != null) {
    RiverRun? nearest;
    double? nearestKm;
    for (final run in runs) {
      final putIn = run.putInCoordinates;
      final lat = putIn?['latitude'];
      final lng = putIn?['longitude'];
      if (lat == null || lng == null) continue;
      final km = distanceKm(position.latitude, position.longitude, lat, lng);
      if (km <= nearbyPutInKm && (nearestKm == null || km < nearestKm)) {
        nearest = run;
        nearestKm = km;
      }
    }
    if (nearest != null) {
      return RunSuggestion(nearest, SuggestionReason.nearestPutIn);
    }
  }

  if (descents.isNotEmpty) {
    final latest = descents.reduce((a, b) => a.date.isAfter(b.date) ? a : b);
    final run = byId[latest.runId];
    if (run != null) return RunSuggestion(run, SuggestionReason.lastLogged);
  }

  for (final id in recentRunIds) {
    final run = byId[id];
    if (run != null) return RunSuggestion(run, SuggestionReason.recentlyViewed);
  }
  return null;
}

/// Crew names from past descents, most frequent first.
List<String> crewSuggestions(List<Descent> descents, {int limit = 8}) {
  final counts = <String, int>{};
  for (final d in descents) {
    for (final name in d.crew ?? const <String>[]) {
      final trimmed = name.trim();
      if (trimmed.isEmpty) continue;
      counts[trimmed] = (counts[trimmed] ?? 0) + 1;
    }
  }
  final names = counts.keys.toList()
    ..sort((a, b) {
      final byCount = counts[b]!.compareTo(counts[a]!);
      return byCount != 0 ? byCount : a.compareTo(b);
    });
  return names.take(limit).toList();
}

/// Great-circle distance in kilometres.
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthKm = 6371.0;
  double rad(double d) => d * math.pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(lat1)) *
          math.cos(rad(lat2)) *
          math.pow(math.sin(dLng / 2), 2);
  return 2 * earthKm * math.asin(math.sqrt(a));
}
