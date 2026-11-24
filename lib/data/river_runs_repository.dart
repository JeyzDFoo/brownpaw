import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/river_run.dart';

/// Reads and writes river runs. Widgets and providers go through this
/// instead of calling Firestore directly, so storage details (collection
/// names, filters, offline caching) live in one place.
class RiverRunsRepository {
  RiverRunsRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _runs =>
      _firestore.collection('river_runs');

  /// All runs [userId] can see: curated runs plus that user's own private
  /// runs, sorted by river.
  ///
  /// The security rules only let a paddler read curated runs
  /// (`visibility == 'public'`) and runs they created, so these are two
  /// queries rather than one read of the whole collection.
  Stream<List<RiverRun>> watchVisibleRuns({String? userId}) {
    final curated = _watchCurated();
    if (userId == null) return curated.map(_sorted);
    final own = _runs
        .where('createdBy', isEqualTo: userId)
        .snapshots()
        .map((s) => s.docs.map(RiverRun.fromFirestore).toList())
        .transform(
          StreamTransformer<List<RiverRun>, List<RiverRun>>.fromHandlers(
            // Losing your own runs shouldn't hide the guide.
            handleError: (e, _, sink) {
              debugPrint('RiverRunsRepository: own runs failed: $e');
              sink.add(const []);
            },
          ),
        );
    return combineLatest(curated, own, (a, b) {
      final byId = <String, RiverRun>{
        for (final run in [...a, ...b])
          if (isVisibleTo(run, userId)) run.riverId: run,
      };
      return _sorted(byId.values);
    });
  }

  /// Curated runs. Until every curated run carries `visibility: 'public'`
  /// (scripts/backfill_run_visibility.py), the query can come back empty;
  /// then this falls back to reading the whole collection, which the old
  /// rules allow.
  Stream<List<RiverRun>> _watchCurated() {
    List<RiverRun> curatedOnly(QuerySnapshot<Map<String, dynamic>> s) => s.docs
        .map(RiverRun.fromFirestore)
        .where((run) => run.verified)
        .toList();

    final public = _runs.where('visibility', isEqualTo: 'public').snapshots();
    return switchMap(public, (snapshot) {
      if (snapshot.docs.isNotEmpty) {
        return Stream.value(curatedOnly(snapshot));
      }
      return _runs.snapshots().map(curatedOnly).handleError((Object e) {
        debugPrint('RiverRunsRepository: legacy read failed: $e');
      });
    });
  }

  static List<RiverRun> _sorted(Iterable<RiverRun> runs) =>
      runs.toList()..sort((a, b) => a.river.compareTo(b.river));

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
    // Not awaited: the write is saved on the device at once and syncs when
    // there's signal; waiting for the server would hang with none.
    _runs
        .doc(riverId)
        .set({
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
        })
        .then<void>(
          (_) {},
          onError: (Object e) => debugPrint('createPrivateRun failed: $e'),
        );
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

/// Emits [combine] of the latest values of [a] and [b] once both have
/// emitted, and again whenever either does.
Stream<R> combineLatest<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A, B) combine,
) {
  late StreamController<R> controller;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;
  A? lastA;
  B? lastB;
  var hasA = false, hasB = false;

  void emit() {
    if (hasA && hasB) controller.add(combine(lastA as A, lastB as B));
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen((v) {
        lastA = v;
        hasA = true;
        emit();
      }, onError: controller.addError);
      subB = b.listen((v) {
        lastB = v;
        hasB = true;
        emit();
      }, onError: controller.addError);
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );
  return controller.stream;
}

/// Maps each event of [source] to a stream and forwards only the latest
/// one's events, cancelling the previous.
Stream<R> switchMap<T, R>(Stream<T> source, Stream<R> Function(T) convert) {
  late StreamController<R> controller;
  StreamSubscription<T>? outer;
  StreamSubscription<R>? inner;
  controller = StreamController<R>(
    onListen: () {
      outer = source.listen((value) {
        inner?.cancel();
        inner = convert(
          value,
        ).listen(controller.add, onError: controller.addError);
      }, onError: controller.addError);
    },
    onCancel: () async {
      await inner?.cancel();
      await outer?.cancel();
    },
  );
  return controller.stream;
}
