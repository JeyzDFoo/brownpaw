import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_provider.dart';

/// State for the favorites feature
class FavoritesState {
  final Set<String> favoriteRunIds;
  final bool isLoading;
  final String? errorMessage;

  FavoritesState({
    Set<String>? favoriteRunIds,
    this.isLoading = false,
    this.errorMessage,
  }) : favoriteRunIds = favoriteRunIds ?? {};

  FavoritesState copyWith({
    Set<String>? favoriteRunIds,
    bool? isLoading,
    String? errorMessage,
  }) {
    return FavoritesState(
      favoriteRunIds: favoriteRunIds ?? this.favoriteRunIds,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }

  bool isFavorite(String runId) => favoriteRunIds.contains(runId);
}

/// Notifier for managing favorites
class FavoritesNotifier extends StateNotifier<FavoritesState> {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  FavoritesNotifier(this._firestore, this._ref) : super(FavoritesState()) {
    _initializeFavorites();
  }

  /// Initialize favorites from Firestore
  Future<void> _initializeFavorites() async {
    final user = _ref.read(userProvider).user;
    if (user == null) {
      state = FavoritesState();
      return;
    }

    try {
      state = state.copyWith(isLoading: true);
      final doc = await _firestore.collection('users').doc(user.uid).get();

      if (doc.exists) {
        final data = doc.data();
        final favorites = data?['favorites'] as List<dynamic>?;
        if (kDebugMode) {
          print('Favorites loaded from Firestore: $favorites');
        }
        if (favorites != null) {
          state = FavoritesState(
            favoriteRunIds: Set<String>.from(favorites),
            isLoading: false,
          );
        } else {
          state = FavoritesState(isLoading: false);
        }
      } else {
        if (kDebugMode) {
          print('User document does not exist in Firestore');
        }
        state = FavoritesState(isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to load favorites: $e',
      );
      if (kDebugMode) {
        print('Error loading favorites: $e');
      }
    }
  }

  /// Toggle favorite status for a run
  Future<void> toggleFavorite(String runId) async {
    final user = _ref.read(userProvider).user;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'You must be signed in to favorite runs',
      );
      return;
    }

    // Optimistically update UI
    final newFavorites = Set<String>.from(state.favoriteRunIds);
    final isFavorite = newFavorites.contains(runId);

    if (isFavorite) {
      newFavorites.remove(runId);
    } else {
      newFavorites.add(runId);
    }

    state = state.copyWith(favoriteRunIds: newFavorites);

    // Update Firestore
    try {
      final userDoc = _firestore.collection('users').doc(user.uid);
      final favoritesList = newFavorites.toList();
      if (kDebugMode) {
        print('Saving favorites to Firestore: $favoritesList');
      }
      await userDoc.set({'favorites': favoritesList}, SetOptions(merge: true));
    } catch (e) {
      // Revert on error
      final revertedFavorites = Set<String>.from(state.favoriteRunIds);
      if (isFavorite) {
        revertedFavorites.add(runId);
      } else {
        revertedFavorites.remove(runId);
      }

      state = state.copyWith(
        favoriteRunIds: revertedFavorites,
        errorMessage: 'Failed to update favorite: $e',
      );

      if (kDebugMode) {
        print('Error updating favorite: $e');
      }
    }
  }

  /// Add a run to favorites
  Future<void> addFavorite(String runId) async {
    if (!state.isFavorite(runId)) {
      await toggleFavorite(runId);
    }
  }

  /// Remove a run from favorites
  Future<void> removeFavorite(String runId) async {
    if (state.isFavorite(runId)) {
      await toggleFavorite(runId);
    }
  }

  /// Clear all favorites
  Future<void> clearAllFavorites() async {
    final user = _ref.read(userProvider).user;
    if (user == null) return;

    try {
      state = state.copyWith(isLoading: true);

      final userDoc = _firestore.collection('users').doc(user.uid);
      await userDoc.update({'favorites': []});

      state = FavoritesState(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to clear favorites: $e',
      );
      if (kDebugMode) {
        print('Error clearing favorites: $e');
      }
    }
  }

  /// Clear error message
  void clearError() {
    state = state.copyWith(errorMessage: null);
  }

  /// Refresh favorites from Firestore
  Future<void> refresh() async {
    await _initializeFavorites();
  }

  /// Clear all favorites (for sign out)
  void clear() {
    state = FavoritesState();
  }
}

/// Provider for favorites functionality
final favoritesProvider =
    StateNotifierProvider<FavoritesNotifier, FavoritesState>((ref) {
      final firestore = ref.watch(firestoreProvider);
      final notifier = FavoritesNotifier(firestore, ref);

      // Listen to auth changes and refresh favorites
      ref.listen(authStateProvider, (previous, next) {
        next.whenData((user) {
          if (user == null) {
            // Clear favorites when user signs out
            notifier.clear();
          } else {
            // Refresh favorites when user signs in
            notifier.refresh();
          }
        });
      });

      return notifier;
    });

/// Provider to check if a specific run is favorited
final isFavoriteProvider = Provider.family<bool, String>((ref, runId) {
  final favoritesState = ref.watch(favoritesProvider);
  return favoritesState.isFavorite(runId);
});

/// Provider for the count of favorites
final favoritesCountProvider = Provider<int>((ref) {
  final favoritesState = ref.watch(favoritesProvider);
  return favoritesState.favoriteRunIds.length;
});
