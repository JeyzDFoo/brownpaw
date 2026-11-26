import 'package:brownpaw/data/account_merge.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> descent(String runId, DateTime date, {String? notes}) => {
  'runId': runId,
  'runName': runId,
  'userId': 'anon',
  'date': Timestamp.fromDate(date),
  'createdAt': Timestamp.fromDate(date),
  'isPublic': false,
  if (notes != null) 'notes': notes,
};

Map<String, dynamic> run(String river, String name, String owner) => {
  'riverId': '$river-$name'.toLowerCase(),
  'river': river,
  'name': name,
  'createdBy': owner,
  'verified': false,
  'visibility': 'private',
};

Map<String, dynamic> alert(String uid, String runId) => {
  'userId': uid,
  'runId': runId,
  'stationId': 'environment_canada_08GA022',
  'minFlow': 10,
  'maxFlow': 40,
  'inRange': true,
  'lastNotifiedAt': Timestamp.now(),
};

void main() {
  final may3 = DateTime(2026, 5, 3, 10);

  test('combines favourites without repeats', () {
    final plan = MergePlan.build(
      from: const AccountData(uid: 'anon', favourites: {'cap', 'lynn'}),
      into: const AccountData(uid: 'me', favourites: {'cap', 'mamquam'}),
    );
    expect(plan.favourites, {'lynn'});
  });

  test('copies descents into the account', () {
    final plan = MergePlan.build(
      from: AccountData(
        uid: 'anon',
        descents: [MergeDoc('d1', descent('cap', may3, notes: 'boof'))],
      ),
      into: const AccountData(uid: 'me'),
    );
    expect(plan.descents, hasLength(1));
    final copy = plan.descents.single;
    expect(copy['userId'], 'me');
    expect(copy['runId'], 'cap');
    expect(copy['notes'], 'boof');
    expect(copy['mergedFrom'], 'anon/d1');
  });

  test('skips a descent already logged on the same run and day', () {
    final plan = MergePlan.build(
      from: AccountData(
        uid: 'anon',
        descents: [
          MergeDoc('d1', descent('cap', may3)),
          MergeDoc('d2', descent('cap', may3.add(const Duration(days: 1)))),
        ],
      ),
      into: AccountData(
        uid: 'me',
        descents: [
          MergeDoc('m1', descent('cap', may3.add(const Duration(hours: 4)))),
        ],
      ),
    );
    expect(plan.descents.map((d) => d['mergedFrom']), ['anon/d2']);
  });

  test('keeps a second lap on the same day', () {
    final plan = MergePlan.build(
      from: AccountData(
        uid: 'anon',
        descents: [
          MergeDoc('d1', descent('cap', may3)),
          MergeDoc('d2', descent('cap', may3)),
        ],
      ),
      into: AccountData(
        uid: 'me',
        descents: [MergeDoc('m1', descent('cap', may3))],
      ),
    );
    expect(plan.descents, hasLength(1));
  });

  test('two laps without an account both come over', () {
    final plan = MergePlan.build(
      from: AccountData(
        uid: 'anon',
        descents: [
          MergeDoc('d1', descent('cap', may3)),
          MergeDoc('d2', descent('cap', may3)),
        ],
      ),
      into: const AccountData(uid: 'me'),
    );
    expect(plan.descents, hasLength(2));
  });

  test('running it again copies nothing', () {
    const from = 'anon';
    final source = AccountData(
      uid: from,
      favourites: const {'cap'},
      descents: [MergeDoc('d1', descent('cap', may3))],
      alerts: [MergeDoc('anon_cap', alert(from, 'cap'))],
    );
    final first = MergePlan.build(
      from: source,
      into: const AccountData(uid: 'me'),
    );
    final after = AccountData(
      uid: 'me',
      favourites: first.favourites,
      descents: [for (final d in first.descents) MergeDoc('x', d)],
      alerts: first.alerts,
    );
    expect(MergePlan.build(from: source, into: after).isEmpty, isTrue);
  });

  test('moves a private run to a new id and follows it everywhere', () {
    final plan = MergePlan.build(
      from: AccountData(
        uid: 'anon',
        favourites: const {'creek-secret'},
        privateRuns: [MergeDoc('creek-secret', run('Creek', 'Secret', 'anon'))],
        descents: [MergeDoc('d1', descent('creek-secret', may3))],
        alerts: [MergeDoc('anon_creek-secret', alert('anon', 'creek-secret'))],
      ),
      into: const AccountData(uid: 'AbC123xyz789'),
    );
    const newId = 'creek-secret-abc123xy';
    expect(plan.privateRuns.single.id, newId);
    expect(plan.privateRuns.single.data['createdBy'], 'AbC123xyz789');
    expect(plan.privateRuns.single.data['riverId'], newId);
    expect(plan.privateRuns.single.data['visibility'], 'private');
    expect(plan.privateRuns.single.data['verified'], false);
    expect(plan.favourites, {newId});
    expect(plan.descents.single['runId'], newId);
    expect(plan.alerts.single.id, 'AbC123xyz789_$newId');
  });

  test('uses the account\'s own private run with the same name', () {
    final plan = MergePlan.build(
      from: AccountData(
        uid: 'anon',
        privateRuns: [MergeDoc('creek-secret', run('Creek', 'Secret', 'anon'))],
        descents: [MergeDoc('d1', descent('creek-secret', may3))],
      ),
      into: AccountData(
        uid: 'me',
        privateRuns: [MergeDoc('mine', run('creek', 'secret', 'me'))],
      ),
    );
    expect(plan.privateRuns, isEmpty);
    expect(plan.descents.single['runId'], 'mine');
  });

  test('alerts move without the function\'s fields; the account\'s win', () {
    final plan = MergePlan.build(
      from: AccountData(
        uid: 'anon',
        alerts: [
          MergeDoc('anon_cap', alert('anon', 'cap')),
          MergeDoc('anon_lynn', alert('anon', 'lynn')),
        ],
      ),
      into: AccountData(
        uid: 'me',
        alerts: [MergeDoc('me_cap', alert('me', 'cap'))],
      ),
    );
    expect(plan.alerts.single.id, 'me_lynn');
    expect(plan.alerts.single.data['userId'], 'me');
    expect(plan.alerts.single.data.containsKey('inRange'), isFalse);
    expect(plan.alerts.single.data.containsKey('lastNotifiedAt'), isFalse);
  });

  test('keeps this phone\'s push token', () {
    final plan = MergePlan.build(
      from: const AccountData(uid: 'anon', fcmTokens: ['phone', 'old']),
      into: const AccountData(uid: 'me', fcmTokens: ['old']),
    );
    expect(plan.fcmTokens, ['phone']);
  });

  test('the same account merges into nothing', () {
    final plan = MergePlan.build(
      from: const AccountData(uid: 'me', favourites: {'cap'}),
      into: const AccountData(uid: 'me'),
    );
    expect(plan.isEmpty, isTrue);
  });
}
