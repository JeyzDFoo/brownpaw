import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/river_run.dart';
import 'favorites_provider.dart';
import 'user_provider.dart';

/// Provider for Firestore instance
final firestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

/// Provider for the search query
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Provider for the selected run ID (for highlighting)
final selectedRunIdProvider = StateProvider<String?>((ref) => null);

/// Provider for the map expanded state
final mapExpandedProvider = StateProvider<bool>((ref) => false);

/// Stream provider for all river runs from Firestore
/// Returns verified runs (including those without verified field) + user's own unverified runs
final riverRunsStreamProvider = StreamProvider<List<RiverRun>>((ref) {
  final firestore = ref.watch(firestoreProvider);
  final user = ref.watch(userProvider).user;

  try {
    // Get all runs and filter client-side
    // (This is needed because existing runs don't have the verified field)
    final allRunsStream = firestore
        .collection('river_runs')
        .orderBy('river')
        .snapshots()
        .handleError((error) {
          debugPrint('❌ Error fetching runs: $error');
        });

    return allRunsStream.map((snapshot) {
      final allRuns = snapshot.docs
          .map((doc) => RiverRun.fromFirestore(doc))
          .toList();

      // Filter: include verified runs (true or null) + user's unverified runs
      final filteredRuns = allRuns.where((run) {
        // If verified is null or true, include it
        if (run.verified) return true;

        // If verified is false, only include if it's the user's run
        if (user != null && run.createdBy == user.uid) return true;

        // Otherwise exclude
        return false;
      }).toList();

      debugPrint(
        '✅ Loaded ${filteredRuns.length} runs (filtered from ${allRuns.length} total)',
      );
      return filteredRuns;
    });
  } catch (e) {
    debugPrint('❌ Fatal error in riverRunsStreamProvider: $e');
    rethrow;
  }
});

/// Provider for creating river runs
final riverRunsProvider = Provider<RiverRunsNotifier>((ref) {
  return RiverRunsNotifier(ref.watch(firestoreProvider));
});

/// Notifier for managing river run operations
class RiverRunsNotifier {
  final FirebaseFirestore _firestore;

  RiverRunsNotifier(this._firestore);

  /// Create a new river run in Firestore
  Future<String> createRun({
    required String name,
    required String river,
    required String userId,
    String province = 'Unknown',
    String? region,
    String difficultyClass = 'Unknown',
  }) async {
    // Generate a river ID from the name
    final riverId = _generateRiverId(river, name);

    final runData = {
      'riverId': riverId,
      'name': name,
      'river': river,
      'province': province,
      'region': region,
      'difficultyClass': difficultyClass,
      'createdBy': userId,
      'verified': false,
      'visibility': 'private',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    await _firestore.collection('river_runs').doc(riverId).set(runData);

    return riverId;
  }

  /// Generate a river ID from river and run name
  String _generateRiverId(String river, String name) {
    final combined = '$river-$name';
    return combined
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
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
