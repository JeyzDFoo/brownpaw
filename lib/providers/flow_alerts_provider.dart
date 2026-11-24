import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/push_service.dart';
import '../data/repositories.dart';
import '../domain/flow_alert.dart';
import '../models/river_run.dart';
import 'user_provider.dart';

/// Ids of the runs the signed-in paddler has flow alerts on.
final alertedRunIdsProvider = StreamProvider<Set<String>>((ref) {
  final uid = ref.watch(userProvider.select((u) => u.user?.uid));
  if (uid == null) return Stream.value(const {});
  return ref.watch(flowAlertsRepositoryProvider).watchRunIds(uid);
});

/// Turns alerts on and off. Turning one on first makes sure this device
/// can receive pushes.
class FlowAlertsController {
  FlowAlertsController(this._ref);
  final Ref _ref;

  String? get _uid => _ref.read(userProvider).user?.uid;

  Future<PushResult> turnOn(RiverRun run) async {
    final uid = _uid;
    final range = alertRangeFor(run);
    if (uid == null || range == null || run.stationId == null) {
      return PushResult.unavailable;
    }
    final push = await _ref.read(pushServiceProvider).enable(uid);
    if (push != PushResult.enabled) return push;
    await _ref.read(flowAlertsRepositoryProvider).add(uid, run, range);
    return PushResult.enabled;
  }

  Future<void> turnOff(RiverRun run) async {
    final uid = _uid;
    if (uid == null) return;
    await _ref.read(flowAlertsRepositoryProvider).remove(uid, run.riverId);
  }
}

final flowAlertsControllerProvider = Provider<FlowAlertsController>(
  FlowAlertsController.new,
);
