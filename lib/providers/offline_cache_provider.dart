import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gauge_repository.dart';
import '../data/repositories.dart';
import 'gauges_provider.dart';

/// Keeps "your gauges" (runs you've starred or logged) ready for when
/// there's no signal on the river.
///
/// While the app is open it listens to each of those gauges' recent
/// readings, so Firestore's on-device cache always holds the latest, and
/// reads a year of daily history once per session, so the charts open
/// offline too. Gauge pages say how old the readings are.
final offlineCacheProvider = Provider<void>((ref) {
  if (!OfflineCache.enabled) return;
  final gauges = ref.watch(yourGaugesProvider).valueOrNull ?? const [];
  final repo = ref.watch(gaugeRepositoryProvider);

  // Best effort: nothing here may stop the app showing.
  final subs = <StreamSubscription<Object?>>[];
  ref.onDispose(() {
    for (final sub in subs) {
      sub.cancel();
    }
  });
  for (final gauge in gauges.take(OfflineCache.maxGauges)) {
    try {
      _keep(repo, gauge.id, subs);
    } catch (e) {
      debugPrint('Offline cache ${gauge.id}: $e');
    }
  }
});

void _keep(
  GaugeRepository repo,
  String id,
  List<StreamSubscription<Object?>> subs,
) {
  subs.add(
    repo
        .watchCurrent(id)
        .listen(
          (_) {},
          onError: (Object e) => debugPrint('Offline cache $id: $e'),
        ),
  );
  if (OfflineCache._historyFetched.add(id)) {
    repo
        .dailyFlows(id, 365)
        .then<void>(
          (_) {},
          onError: (Object e) {
            OfflineCache._historyFetched.remove(id);
            debugPrint('Offline history $id: $e');
          },
        );
  }
}

abstract final class OfflineCache {
  /// Turned off in widget tests, which have no Firestore.
  static bool enabled = true;

  /// Enough for anyone's regular runs without downloading every gauge.
  static const maxGauges = 25;

  static final _historyFetched = <String>{};
}
