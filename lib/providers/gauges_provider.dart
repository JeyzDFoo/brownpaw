import 'package:flutter/widgets.dart' show AppLifecycleListener;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gauge_repository.dart';
import '../data/location_service.dart';
import '../data/repositories.dart';
import '../domain/flow_ranges.dart' show FlowUnit;
import '../domain/gauges.dart';
import 'check_in_provider.dart' show locationAccessProvider;
import 'descents_provider.dart';
import 'favorites_provider.dart';
import 'realtime_flow_provider.dart';
import 'river_runs_provider.dart';

/// Every gauge that at least one visible run is read against.
final gaugesProvider = Provider<AsyncValue<List<Gauge>>>((ref) {
  final names = ref.watch(stationNamesProvider).valueOrNull ?? const {};
  return ref
      .watch(riverRunsStreamProvider)
      .whenData((runs) => gaugesFromRuns(runs, stationNames: names));
});

/// Station summaries (official name, latest flow) by `station_current` id.
final stationsProvider = StreamProvider<Map<String, StationSummary>>(
  (ref) => ref.watch(gaugeRepositoryProvider).watchStations(),
);

/// Official station names by `station_current` id.
final stationNamesProvider = Provider<AsyncValue<Map<String, String>>>(
  (ref) => ref
      .watch(stationsProvider)
      .whenData(
        (stations) => {
          for (final MapEntry(:key, :value) in stations.entries)
            if (value.name != null) key: value.name!,
        },
      ),
);

/// Ids of the runs the paddler has favourited.
final favouriteRunIdsProvider = Provider<Set<String>>(
  (ref) => ref.watch(favoritesProvider).favoriteRunIds,
);

/// Gauges for runs the paddler has favourited or logged.
final yourGaugesProvider = Provider<AsyncValue<List<Gauge>>>((ref) {
  final favourites = ref.watch(favouriteRunIdsProvider);
  final descents = ref.watch(allDescentsProvider).valueOrNull ?? const [];
  return ref
      .watch(gaugesProvider)
      .whenData(
        (gauges) =>
            yourGauges(gauges, favouriteRunIds: favourites, descents: descents),
      );
});

/// Where the device is, for putting nearby gauges first. Null until the
/// paddler has allowed location; this never shows a permission prompt.
/// Read again whenever the app comes back to the front, so the order
/// follows the paddler from home to the river.
final devicePositionProvider = FutureProvider<LatLng?>((ref) async {
  final listener = AppLifecycleListener(onResume: ref.invalidateSelf);
  ref.onDispose(listener.dispose);
  // Re-read when location is switched on from the banner.
  ref.watch(locationAccessProvider);
  final service = ref.read(locationServiceProvider);
  if (await service.access() != LocationAccess.granted) return null;
  return service.currentPosition();
});

/// The Gauges tab's Starred, Recent and All lists, each with what's running
/// first, then what's nearest, then by name. Gauges show up while flows and
/// location are still loading, and re-sort when they arrive.
///
/// Starred and Recent are judged on the same live readings their rows
/// show, so a gauge marked Medium is never sorted below one with no
/// status. All uses each station's stored summary, to avoid fetching
/// every gauge at once.
final gaugeSectionsProvider = Provider<AsyncValue<GaugeSections>>((ref) {
  final favourites = ref.watch(favouriteRunIdsProvider);
  final descents = ref.watch(allDescentsProvider).valueOrNull ?? const [];
  final stored = ref.watch(stationsProvider).valueOrNull ?? const {};
  final position = ref.watch(devicePositionProvider).valueOrNull;
  return ref.watch(gaugesProvider).whenData((gauges) {
    final split = gaugeSections(
      gauges,
      favouriteRunIds: favourites,
      descents: descents,
    );
    final stations = {...stored};
    for (final g in [...split.starred, ...split.recent]) {
      final live = ref.watch(realtimeFlowStreamProvider(g.stationId));
      final latest = live.valueOrNull;
      if (latest != null && latest.timestamp != null) {
        stations[g.id] = StationSummary.fromLive(latest);
      } else if (live.hasValue) {
        // No recent reading: don't call it running on an old summary.
        stations.remove(g.id);
      }
    }
    return gaugeSections(
      gauges,
      favouriteRunIds: favourites,
      descents: descents,
      stations: stations,
      position: position,
    );
  });
});

/// One gauge by its `station_current` id, or null when no run uses it.
final gaugeProvider = Provider.family<AsyncValue<Gauge?>, String>(
  (ref, id) => ref
      .watch(gaugesProvider)
      .whenData((gauges) => gauges.where((g) => g.id == id).firstOrNull),
);

/// Daily mean flows (or, in metres, water levels) for a station over the
/// last `days` days.
final gaugeDailyFlowsProvider =
    FutureProvider.family<
      List<FlowPoint>,
      ({String stationId, int days, FlowUnit unit})
    >(
      (ref, key) => ref
          .watch(gaugeRepositoryProvider)
          .dailyFlows(key.stationId, key.days, unit: key.unit),
    );
