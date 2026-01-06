import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/descent.dart';
import 'user_provider.dart';

/// Provider for descents collection
final descentsProvider = StateNotifierProvider<DescentsNotifier, DescentsState>(
  (ref) {
    final firestore = ref.watch(firestoreProvider);
    return DescentsNotifier(firestore, ref);
  },
);

/// Provider for getting descents for a specific run
final runDescentsProvider = StreamProvider.family<List<Descent>, String>((
  ref,
  runId,
) {
  final user = ref.watch(userProvider).user;
  if (user == null) return Stream.value([]);

  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('users')
      .doc(user.uid)
      .collection('descents')
      .where('runId', isEqualTo: runId)
      .orderBy('date', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Descent.fromFirestore(doc)).toList(),
      );
});

/// Provider for getting descent count for a specific run
final runDescentCountProvider = Provider.family<AsyncValue<int>, String>((
  ref,
  runId,
) {
  return ref
      .watch(runDescentsProvider(runId))
      .when(
        data: (descents) => AsyncValue.data(descents.length),
        loading: () => const AsyncValue.data(0),
        error: (err, stack) => const AsyncValue.data(0),
      );
});

/// Provider for all user's descents
final allDescentsProvider = StreamProvider<List<Descent>>((ref) {
  final user = ref.watch(userProvider).user;
  if (user == null) return Stream.value([]);

  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('descents')
      .where('userId', isEqualTo: user.uid)
      .orderBy('date', descending: true)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Descent.fromFirestore(doc)).toList(),
      );
});

/// Provider for public descents of a specific run (from all users)
final publicDescentsProvider = StreamProvider.family<List<Descent>, String>((
  ref,
  runId,
) {
  final firestore = ref.watch(firestoreProvider);
  return firestore
      .collection('descents')
      .where('runId', isEqualTo: runId)
      .where('isPublic', isEqualTo: true)
      .orderBy('date', descending: true)
      .limit(50)
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Descent.fromFirestore(doc)).toList(),
      );
});

/// State for descents
class DescentsState {
  final bool isLoading;
  final String? errorMessage;

  DescentsState({this.isLoading = false, this.errorMessage});

  DescentsState copyWith({bool? isLoading, String? errorMessage}) {
    return DescentsState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}

/// Notifier for managing descents
class DescentsNotifier extends StateNotifier<DescentsState> {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  DescentsNotifier(this._firestore, this._ref) : super(DescentsState());

  /// Add a new descent
  Future<String?> addDescent({
    required String runId,
    required String runName,
    required DateTime date,
    double? flow,
    String? flowUnit,
    String? notes,
    int? rating,
    String? difficulty,
    bool isPublic = false,
  }) async {
    final user = _ref.read(userProvider).user;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'You must be signed in to log descents',
      );
      return null;
    }

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final descent = Descent(
        id: '', // Will be set by Firestore
        runId: runId,
        runName: runName,
        userId: user.uid,
        date: date,
        flow: flow,
        flowUnit: flowUnit,
        notes: notes,
        rating: rating,
        difficulty: difficulty,
        isPublic: isPublic,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection('descents')
          .add(descent.toFirestore());

      state = state.copyWith(isLoading: false);

      if (kDebugMode) {
        print('Descent added successfully: ${docRef.id}');
      }

      return docRef.id;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to add descent: $e',
      );
      if (kDebugMode) {
        print('Error adding descent: $e');
      }
      return null;
    }
  }

  /// Update an existing descent
  Future<bool> updateDescent({
    required String descentId,
    DateTime? date,
    double? flow,
    String? flowUnit,
    String? notes,
    int? rating,
    String? difficulty,
  }) async {
    final user = _ref.read(userProvider).user;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'You must be signed in to update descents',
      );
      return false;
    }

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      final updates = <String, dynamic>{'updatedAt': Timestamp.now()};

      if (date != null) updates['date'] = Timestamp.fromDate(date);
      if (flow != null) updates['flow'] = flow;
      if (flowUnit != null) updates['flowUnit'] = flowUnit;
      if (notes != null) updates['notes'] = notes;
      if (rating != null) updates['rating'] = rating;
      if (difficulty != null) updates['difficulty'] = difficulty;

      await _firestore.collection('descents').doc(descentId).update(updates);

      state = state.copyWith(isLoading: false);

      if (kDebugMode) {
        print('Descent updated successfully: $descentId');
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to update descent: $e',
      );
      if (kDebugMode) {
        print('Error updating descent: $e');
      }
      return false;
    }
  }

  /// Delete a descent
  Future<bool> deleteDescent(String descentId) async {
    final user = _ref.read(userProvider).user;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'You must be signed in to delete descents',
      );
      return false;
    }

    try {
      state = state.copyWith(isLoading: true, errorMessage: null);

      await _firestore.collection('descents').doc(descentId).delete();

      state = state.copyWith(isLoading: false);

      if (kDebugMode) {
        print('Descent deleted successfully: $descentId');
      }

      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to delete descent: $e',
      );
      if (kDebugMode) {
        print('Error deleting descent: $e');
      }
      return false;
    }
  }
}
