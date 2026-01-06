import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_run.dart';

/// Provider for the search query
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for the selected run ID (for highlighting)
final selectedRunIdProvider = StateProvider<String?>((ref) => null);

/// Provider for the map expanded state
final mapExpandedProvider = StateProvider<bool>((ref) => false);

/// Stream provider for all river runs from Firestore
final riverRunsStreamProvider = StreamProvider<List<RiverRun>>((ref) {
  return FirebaseFirestore.instance
      .collection('river_runs')
      .orderBy('river')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => RiverRun.fromFirestore(doc)).toList(),
      );
});

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
