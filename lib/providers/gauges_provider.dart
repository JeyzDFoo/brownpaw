import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/gauges.dart';
import 'descents_provider.dart';
import 'favorites_provider.dart';
import 'river_runs_provider.dart';

/// Every gauge that at least one visible run is read against.
final gaugesProvider = Provider<AsyncValue<List<Gauge>>>(
  (ref) => ref.watch(riverRunsStreamProvider).whenData(gaugesFromRuns),
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
