import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/repositories.dart';
import '../data/river_runs_repository.dart';
import '../models/river_run.dart';
import 'favorites_provider.dart';
import 'user_provider.dart';

/// Provider for the search query
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for the selected run ID (for highlighting)
final selectedRunIdProvider = StateProvider<String?>((ref) => null);

/// Provider for the map expanded state
final mapExpandedProvider = StateProvider<bool>((ref) => false);

/// All runs the signed-in user can see: curated runs plus their own
/// private ones.
final riverRunsStreamProvider = StreamProvider<List<RiverRun>>((ref) {
  final userId = ref.watch(userProvider.select((u) => u.user?.uid));
  return ref
      .watch(riverRunsRepositoryProvider)
      .watchVisibleRuns(userId: userId);
});

/// One run by id, updating live. Null if it doesn't exist.
final riverRunProvider = StreamProvider.family<RiverRun?, String>(
  (ref, runId) => ref.watch(riverRunsRepositoryProvider).watchRun(runId),
);

/// Provider for creating river runs
final riverRunsProvider = Provider<RiverRunsNotifier>((ref) {
  return RiverRunsNotifier(ref.watch(riverRunsRepositoryProvider));
});

/// Creates runs on behalf of the log screen.
class RiverRunsNotifier {
  final RiverRunsRepository _repository;

  RiverRunsNotifier(this._repository);

  /// Create a new private run and return its id.
  Future<String> createRun({
    required String name,
    required String river,
    required String userId,
    String province = 'Unknown',
    String? region,
    String difficultyClass = 'Unknown',
  }) {
    return _repository.createPrivateRun(
      name: name,
      river: river,
      userId: userId,
      province: province,
      region: region,
      difficultyClass: difficultyClass,
    );
  }
}

/// Provider for filtered river runs based on search query
final filteredRiverRunsProvider = Provider<AsyncValue<List<RiverRun>>>((ref) {
  final runsAsync = ref.watch(riverRunsStreamProvider);
  final searchQuery = ref.watch(searchQueryProvider);

  return runsAsync.whenData((runs) {
    if (searchQuery.isEmpty) return runs;

    final query = searchQuery.toLowerCase();
    return runs.where((run) {
      return run.name.toLowerCase().contains(query) ||
          run.river.toLowerCase().contains(query) ||
          run.province.toLowerCase().contains(query) ||
          (run.region?.toLowerCase().contains(query) ?? false);
    }).toList();
  });
});

/// Provider for favorite river runs only
final favoriteRiverRunsProvider = Provider<AsyncValue<List<RiverRun>>>((ref) {
  final runsAsync = ref.watch(riverRunsStreamProvider);
  final favoritesState = ref.watch(favoritesProvider);

  return runsAsync.whenData((runs) {
    debugPrint('favoriteRiverRunsProvider - Total runs: ${runs.length}');
    debugPrint(
      'favoriteRiverRunsProvider - Favorite IDs: ${favoritesState.favoriteRunIds}',
    );

    if (favoritesState.favoriteRunIds.isEmpty) {
      debugPrint(
        'favoriteRiverRunsProvider - No favorites, returning empty list',
      );
      return [];
    }

    final favoriteRuns = runs.where((run) {
      final isFavorite = favoritesState.favoriteRunIds.contains(run.riverId);
      if (isFavorite) {
        debugPrint(
          'favoriteRiverRunsProvider - Found favorite: ${run.riverId} - ${run.name}',
        );
      }
      return isFavorite;
    }).toList();

    debugPrint(
      'favoriteRiverRunsProvider - Returning ${favoriteRuns.length} favorite runs',
    );
    return favoriteRuns;
  });
});
