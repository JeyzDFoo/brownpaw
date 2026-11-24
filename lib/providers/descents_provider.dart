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

/// The signed-in user's descents of one run, newest first.
///
/// Derived from [allDescentsProvider]; descents live in the top-level
/// `descents` collection (the old `users/{uid}/descents` path is denied by
/// the security rules and was always empty).
final runDescentsProvider = Provider.family<AsyncValue<List<Descent>>, String>(
  (ref, runId) => ref
      .watch(allDescentsProvider)
      .whenData((all) => all.where((d) => d.runId == runId).toList()),
);

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
    List<String>? crew,
    bool isPublic = false,
  }) async {
    final user = _ref.read(userProvider).user;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'You must be signed in to log descents',
      );
      return null;
    }

    final docRef = _firestore.collection('descents').doc();
    final descent = Descent(
      id: docRef.id,
      runId: runId,
      runName: runName,
      userId: user.uid,
      date: date,
      flow: flow,
      flowUnit: flowUnit,
      notes: notes,
      rating: rating,
      difficulty: difficulty,
      crew: crew,
      isPublic: isPublic,
      createdAt: DateTime.now(),
    );

    // Firestore saves the entry on the device straight away and the
    // logbook shows it; the returned future only completes when the server
    // confirms, which at a put-in with no signal can be hours. So don't
    // wait for it.
    _write(docRef.set(descent.toFirestore()), 'add descent');
    return docRef.id;
  }

  /// Runs a Firestore write in the background, recording a failure (e.g.
  /// the server rejecting it once back online) in [state].
  void _write(Future<void> write, String what) {
    state = state.copyWith(errorMessage: null);
    write.then<void>(
      (_) {},
      onError: (Object e) {
        if (mounted) {
          state = state.copyWith(errorMessage: "Couldn't $what: $e");
        }
        debugPrint('DescentsNotifier: $what failed: $e');
      },
    );
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
    bool? isPublic,
  }) async {
    final user = _ref.read(userProvider).user;
    if (user == null) {
      state = state.copyWith(
        errorMessage: 'You must be signed in to update descents',
      );
      return false;
    }

    final updates = <String, dynamic>{'updatedAt': Timestamp.now()};

    if (date != null) updates['date'] = Timestamp.fromDate(date);
    if (flow != null) updates['flow'] = flow;
    if (flowUnit != null) updates['flowUnit'] = flowUnit;
    if (notes != null) updates['notes'] = notes;
    if (rating != null) updates['rating'] = rating;
    if (difficulty != null) updates['difficulty'] = difficulty;
    if (isPublic != null) updates['isPublic'] = isPublic;

    _write(
      _firestore.collection('descents').doc(descentId).update(updates),
      'update descent',
    );
    return true;
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

    _write(
      _firestore.collection('descents').doc(descentId).delete(),
      'delete descent',
    );
    return true;
  }
}
