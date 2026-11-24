import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/flow_alert.dart';
import '../models/river_run.dart';
import 'gauge_repository.dart';

/// Flow alerts live in `flow_alerts/{userId}_{runId}`. A Cloud Function
/// reads them after each gauge update and sends a push when a run comes
/// into range.
class FlowAlertsRepository {
  FlowAlertsRepository(this._firestore);
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _alerts =>
      _firestore.collection('flow_alerts');

  static String idFor(String userId, String runId) => '${userId}_$runId';

  /// Ids of the runs [userId] has alerts on.
  Stream<Set<String>> watchRunIds(String userId) => _alerts
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((s) => {for (final d in s.docs) d.data()['runId'] as String});

  Future<void> add(String userId, RiverRun run, AlertRange range) =>
      _alerts.doc(idFor(userId, run.riverId)).set({
        'userId': userId,
        'runId': run.riverId,
        'runName': run.name,
        'river': run.river,
        'stationId': GaugeRepository.docIdFor(run.stationId!),
        'minFlow': range.min,
        'maxFlow': range.max,
        'word': range.word,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> remove(String userId, String runId) =>
      _alerts.doc(idFor(userId, runId)).delete();
}
