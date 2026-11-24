import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/river_run.dart';

/// Reads and writes river runs. Widgets and providers go through this
/// instead of calling Firestore directly, so storage details (collection
/// names, filters, offline caching) live in one place.
class RiverRunsRepository {
  RiverRunsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _runs =>
      _firestore.collection('river_runs');

  /// All runs [userId] can see: curated runs (verified, or older records
  /// with no `verified` field) plus that user's own private runs.
  Stream<List<RiverRun>> watchVisibleRuns({String? userId}) {
    return _runs
        .orderBy('river')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(RiverRun.fromFirestore)
              .where((run) => isVisibleTo(run, userId))
              .toList(),
        );
  }

  /// One run, updating live. Emits null if it doesn't exist.
  Stream<RiverRun?> watchRun(String runId) {
    return _runs
        .doc(runId)
        .snapshots()
        .map((doc) => doc.exists ? RiverRun.fromFirestore(doc) : null);
  }

  /// One run, read once. Null if it doesn't exist.
  Future<RiverRun?> getRun(String runId) async {
    final doc = await _runs.doc(runId).get();
    return doc.exists ? RiverRun.fromFirestore(doc) : null;
  }

  /// Adds a private, unverified run for [userId] and returns its id.
  Future<String> createPrivateRun({
    required String name,
    required String river,
    required String userId,
    String province = 'Unknown',
    String? region,
    String difficultyClass = 'Unknown',
  }) async {
    final riverId = runIdFor(river, name);
    await _runs.doc(riverId).set({
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
    });
    return riverId;
  }

  /// Whether [run] should be listed for [userId].
  static bool isVisibleTo(RiverRun run, String? userId) =>
      run.verified || (userId != null && run.createdBy == userId);

  /// A stable, URL-safe id from a river and run name,
  /// e.g. "Chilliwack", "Tamihi" -> "chilliwack-tamihi".
  static String runIdFor(String river, String name) {
    return '$river-$name'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }
}
