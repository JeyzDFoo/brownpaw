import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories.dart';
import '../domain/dam_release.dart';

/// A dam's published release schedule by `station_current` id, updating.
final releaseScheduleProvider = StreamProvider.family<ReleaseSchedule?, String>(
  (ref, stationId) =>
      ref.watch(gaugeRepositoryProvider).watchReleaseSchedule(stationId),
);

/// The time, ticking each minute, so "Releasing until 11 PM" turns into
/// "Next release tomorrow" without waiting for new data.
final releaseClockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
});
