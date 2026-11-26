import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Brings what someone made without an account (favourites, logbook,
/// private runs, flow alerts) into the Apple or Google account they then
/// sign in to, when that account already exists and the two can't simply
/// be linked.
///
/// The rules only let a paddler write their own documents, so the
/// anonymous account's data is read while still signed in as it
/// ([AccountMergeRepository.snapshot]), then copied in as the signed-in
/// account ([AccountMergeRepository.apply]). The anonymous originals are
/// left where they are: nothing is deleted, so a failed copy never loses
/// anything.

/// One Firestore document: its id and fields.
class MergeDoc {
  const MergeDoc(this.id, this.data);
  final String id;
  final Map<String, dynamic> data;
}

/// What one account holds.
class AccountData {
  const AccountData({
    required this.uid,
    this.favourites = const {},
    this.fcmTokens = const [],
    this.descents = const [],
    this.privateRuns = const [],
    this.alerts = const [],
  });

  final String uid;
  final Set<String> favourites;
  final List<String> fcmTokens;
  final List<MergeDoc> descents;
  final List<MergeDoc> privateRuns;
  final List<MergeDoc> alerts;

  bool get isEmpty =>
      favourites.isEmpty &&
      descents.isEmpty &&
      privateRuns.isEmpty &&
      alerts.isEmpty;
}

/// The writes that bring [AccountData] from one account into another.
class MergePlan {
  const MergePlan({
    this.favourites = const {},
    this.fcmTokens = const [],
    this.descents = const [],
    this.privateRuns = const [],
    this.alerts = const [],
  });

  /// Favourites to add to the account (already remapped).
  final Set<String> favourites;
  final List<String> fcmTokens;

  /// New descents; their ids are left to Firestore.
  final List<Map<String, dynamic>> descents;

  /// Private runs to create, by their new id.
  final List<MergeDoc> privateRuns;

  /// Flow alerts to create, by their `{uid}_{runId}` id.
  final List<MergeDoc> alerts;

  bool get isEmpty =>
      favourites.isEmpty &&
      fcmTokens.isEmpty &&
      descents.isEmpty &&
      privateRuns.isEmpty &&
      alerts.isEmpty;

  /// Works out what to copy from [from] into [into] so nothing is lost and
  /// nothing is doubled:
  /// - favourites are combined;
  /// - a descent is skipped when [into] holds an earlier copy of it, or
  ///   already logs that run on that day as many times (so a paddle logged
  ///   in both accounts shows once, but a second lap is still kept);
  /// - private runs get a new id owned by [into] (run ids are shared by
  ///   everyone), unless [into] already has a private run with the same
  ///   river and name, which is used instead; descents, favourites and
  ///   alerts follow the new id;
  /// - an alert is skipped when [into] already has one on that run, so
  ///   the account keeps its own range.
  static MergePlan build({
    required AccountData from,
    required AccountData into,
  }) {
    if (from.uid == into.uid) return const MergePlan();

    // Private runs: find or make a home for each in the target account.
    final runIdMap = <String, String>{};
    final newRuns = <MergeDoc>[];
    final intoRunIds = {for (final r in into.privateRuns) r.id};
    final intoRunByName = {
      for (final r in into.privateRuns) _runKey(r.data): r.id,
    };
    for (final run in from.privateRuns) {
      final existing = intoRunByName[_runKey(run.data)];
      if (existing != null) {
        runIdMap[run.id] = existing;
        continue;
      }
      final newId = privateRunIdFor(run.id, into.uid);
      runIdMap[run.id] = newId;
      if (intoRunIds.contains(newId)) continue;
      newRuns.add(
        MergeDoc(newId, {
          ...run.data,
          'riverId': newId,
          'createdBy': into.uid,
          'verified': false,
          'visibility': 'private',
          'mergedFrom': '${from.uid}/${run.id}',
        }),
      );
    }
    String remap(String runId) => runIdMap[runId] ?? runId;

    final favourites = {
      for (final id in from.favourites) remap(id),
    }.difference(into.favourites);

    final intoTokens = into.fcmTokens.toSet();
    final tokens = [
      for (final t in from.fcmTokens)
        if (!intoTokens.contains(t)) t,
    ];

    // Descents.
    final copied = {
      for (final d in into.descents)
        if (d.data['mergedFrom'] is String) d.data['mergedFrom'] as String,
    };
    // How many times each run and day is logged in the account itself
    // (not counting earlier copies).
    final logged = <String, int>{};
    for (final d in into.descents) {
      if (d.data['mergedFrom'] is String) continue;
      final key = _descentKey(d.data['runId'], d.data['date']);
      logged[key] = (logged[key] ?? 0) + 1;
    }
    final descents = <Map<String, dynamic>>[];
    for (final d in from.descents) {
      final source = '${from.uid}/${d.id}';
      if (copied.contains(source)) continue;
      final runId = remap('${d.data['runId'] ?? ''}');
      final key = _descentKey(runId, d.data['date']);
      final already = logged[key] ?? 0;
      if (already > 0) {
        logged[key] = already - 1;
        continue;
      }
      descents.add({
        ...d.data,
        'userId': into.uid,
        'runId': runId,
        'mergedFrom': source,
      });
    }

    // Flow alerts.
    final alertRuns = {for (final a in into.alerts) '${a.data['runId']}'};
    final alerts = <MergeDoc>[];
    for (final a in from.alerts) {
      final runId = remap('${a.data['runId'] ?? ''}');
      if (runId.isEmpty || !alertRuns.add(runId)) continue;
      final data = {...a.data, 'userId': into.uid, 'runId': runId}
        ..remove('inRange')
        ..remove('lastNotifiedAt');
      alerts.add(MergeDoc('${into.uid}_$runId', data));
    }

    return MergePlan(
      favourites: favourites,
      fcmTokens: tokens,
      descents: descents,
      privateRuns: newRuns,
      alerts: alerts,
    );
  }

  /// The id a private run takes when it moves to [uid]'s account.
  static String privateRunIdFor(String runId, String uid) {
    final tag = uid.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    return '$runId-${tag.length > 8 ? tag.substring(0, 8) : tag}';
  }

  static String _runKey(Map<String, dynamic> run) =>
      '${run['river'] ?? ''}|${run['name'] ?? ''}'.toLowerCase().trim();

  static String _descentKey(Object? runId, Object? date) {
    final day = switch (date) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      _ => null,
    };
    final local = day?.toLocal();
    return '$runId|${local?.year}-${local?.month}-${local?.day}';
  }
}

/// Reads and writes the account data that [MergePlan] works on.
class AccountMergeRepository {
  AccountMergeRepository(this._firestore);
  final FirebaseFirestore _firestore;

  /// Everything [uid] holds. Run while signed in as [uid].
  Future<AccountData> snapshot(String uid) async {
    final results = await Future.wait([
      _firestore.collection('users').doc(uid).get(),
      _firestore.collection('descents').where('userId', isEqualTo: uid).get(),
      _firestore
          .collection('river_runs')
          .where('createdBy', isEqualTo: uid)
          .get(),
      _firestore
          .collection('flow_alerts')
          .where('userId', isEqualTo: uid)
          .get(),
    ]);
    final user = (results[0] as DocumentSnapshot<Map<String, dynamic>>).data();
    List<MergeDoc> docs(Object r) => [
      for (final d in (r as QuerySnapshot<Map<String, dynamic>>).docs)
        MergeDoc(d.id, d.data()),
    ];
    return AccountData(
      uid: uid,
      favourites: {...?(user?['favorites'] as List?)?.whereType<String>()},
      fcmTokens: [...?(user?['fcmTokens'] as List?)?.whereType<String>()],
      descents: docs(results[1]),
      privateRuns: docs(results[2]),
      alerts: docs(results[3]),
    );
  }

  /// Copies [from] into [intoUid]'s account. Run while signed in as
  /// [intoUid]. Returns what was written.
  Future<MergePlan> apply(AccountData from, String intoUid) async {
    final into = await snapshot(intoUid);
    final plan = MergePlan.build(from: from, into: into);
    if (plan.isEmpty) return plan;

    final writes = <void Function(WriteBatch)>[
      for (final run in plan.privateRuns)
        (b) => b.set(_firestore.collection('river_runs').doc(run.id), run.data),
      for (final d in plan.descents)
        (b) => b.set(_firestore.collection('descents').doc(), d),
      for (final a in plan.alerts)
        (b) => b.set(_firestore.collection('flow_alerts').doc(a.id), a.data),
      if (plan.favourites.isNotEmpty || plan.fcmTokens.isNotEmpty)
        (b) => b.set(_firestore.collection('users').doc(intoUid), {
          if (plan.favourites.isNotEmpty)
            'favorites': FieldValue.arrayUnion(plan.favourites.toList()),
          if (plan.fcmTokens.isNotEmpty)
            'fcmTokens': FieldValue.arrayUnion(plan.fcmTokens),
        }, SetOptions(merge: true)),
    ];

    // Firestore allows 500 writes a batch. The writes land on the device at
    // once and sync when there's signal, so don't wait long for the server.
    for (var i = 0; i < writes.length; i += 400) {
      final batch = _firestore.batch();
      for (final w in writes.skip(i).take(400)) {
        w(batch);
      }
      await batch.commit().timeout(
        const Duration(seconds: 15),
        onTimeout: () => debugPrint('Account merge: syncing in background'),
      );
    }
    return plan;
  }
}
