import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/river_run.dart';
import 'river_runs_provider.dart';

const String _recentRunsKey = 'recent_river_runs';
const int _maxRecentRuns = 10;

/// Provider for managing recently selected river runs
final recentRunsProvider =
    StateNotifierProvider<RecentRunsNotifier, List<String>>((ref) {
      return RecentRunsNotifier(ref);
    });

class RecentRunsNotifier extends StateNotifier<List<String>> {
  final Ref ref;

  RecentRunsNotifier(this.ref) : super([]) {
    _loadRecentRuns();
  }

  /// Load recent run IDs from SharedPreferences
  Future<void> _loadRecentRuns() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final recentIds = prefs.getStringList(_recentRunsKey) ?? [];
      state = recentIds;
    } catch (e) {
      print('❌ Error loading recent runs: $e');
      state = [];
    }
  }

  /// Add a run to the recent list (moves to top if already exists)
  Future<void> addRecentRun(String runId) async {
    try {
      final updatedList = [runId];

      // Add other runs (excluding the current one to avoid duplicates)
      for (final id in state) {
        if (id != runId && updatedList.length < _maxRecentRuns) {
          updatedList.add(id);
        }
      }

      state = updatedList;

      // Persist to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_recentRunsKey, updatedList);

      print('✅ Added $runId to recent runs');
    } catch (e) {
      print('❌ Error saving recent run: $e');
    }
  }

  /// Get RiverRun objects for recent run IDs
  Future<List<RiverRun>> getRecentRuns() async {
    if (state.isEmpty) return [];

    try {
      final allRunsAsync = ref.read(riverRunsStreamProvider);

      return allRunsAsync.when(
        data: (runs) {
          final recentRuns = <RiverRun>[];
          for (final runId in state) {
            final run = runs.firstWhere(
              (r) => r.riverId == runId,
              orElse: () =>
                  runs.first, // Fallback, though this shouldn't happen
            );
            if (run.riverId == runId) {
              recentRuns.add(run);
            }
          }
          return recentRuns;
        },
        loading: () => [],
        error: (_, __) => [],
      );
    } catch (e) {
      print('❌ Error getting recent runs: $e');
      return [];
    }
  }

  /// Clear all recent runs
  Future<void> clearRecentRuns() async {
    try {
      state = [];
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_recentRunsKey);
      print('✅ Cleared recent runs');
    } catch (e) {
      print('❌ Error clearing recent runs: $e');
    }
  }
}

/// Provider that returns actual RiverRun objects for recent runs
final recentRunsListProvider = FutureProvider<List<RiverRun>>((ref) async {
  final recentRunIds = ref.watch(recentRunsProvider);

  if (recentRunIds.isEmpty) return [];

  final allRunsAsync = await ref.watch(riverRunsStreamProvider.future);

  final recentRuns = <RiverRun>[];
  for (final runId in recentRunIds) {
    try {
      final run = allRunsAsync.firstWhere((r) => r.riverId == runId);
      recentRuns.add(run);
    } catch (e) {
      // Run not found, skip it
      continue;
    }
  }

  return recentRuns;
});
