import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gauge_repository.dart';
import '../data/repositories.dart';
import '../domain/gauges.dart';
import 'descents_provider.dart';
import 'favorites_provider.dart';
import 'river_runs_provider.dart';

/// Every gauge that at least one visible run is read against.
final gaugesProvider = Provider<AsyncValue<List<Gauge>>>((ref) {
  final names = ref.watch(stationNamesProvider).value ?? const {};
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
  final descents = ref.watch(allDescentsProvider).value ?? const [];
  return ref
      .watch(gaugesProvider)
      .whenData(
        (gauges) =>
            yourGauges(gauges, favouriteRunIds: favourites, descents: descents),
      );
});

/// One gauge by its `station_current` id, or null when no run uses it.
final gaugeProvider = Provider.family<AsyncValue<Gauge?>, String>(
  (ref, id) => ref
      .watch(gaugesProvider)
      .whenData((gauges) => gauges.where((g) => g.id == id).firstOrNull),
);

/// Daily mean flows for a station over the last `days` days.
final gaugeDailyFlowsProvider =
    FutureProvider.family<List<FlowPoint>, ({String stationId, int days})>(
      (ref, key) => ref
          .watch(gaugeRepositoryProvider)
          .dailyFlows(key.stationId, key.days),
    );
