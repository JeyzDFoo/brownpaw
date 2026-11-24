import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/location_service.dart';
import '../data/repositories.dart';
import '../domain/run_suggestion.dart';
import '../models/river_run.dart';
import 'river_runs_provider.dart';

/// A run whose put-in the paddler is standing at, with today's flow.
class PutInCheckIn {
  const PutInCheckIn(this.run, {this.flow});
  final RiverRun run;
  final double? flow;
}

final locationAccessProvider = FutureProvider<LocationAccess>(
  (ref) => ref.watch(locationServiceProvider).access(),
);

/// The run whose put-in is within [nearbyPutInKm] of the device, if any.
/// Only reads the location when access is already granted, so opening the
/// app never shows a permission prompt on its own.
final putInCheckInProvider = FutureProvider<PutInCheckIn?>((ref) async {
  final access = await ref.watch(locationAccessProvider.future);
  if (access != LocationAccess.granted) return null;
  final runs = await ref.watch(riverRunsStreamProvider.future);
  final position = await ref.read(locationServiceProvider).currentPosition();
  if (position == null) return null;

  final suggestion = suggestRun(runs: runs, position: position);
  if (suggestion == null ||
      suggestion.reason != SuggestionReason.nearestPutIn) {
    return null;
  }
  final run = suggestion.run;
  double? flow;
  if (run.stationId != null) {
    try {
      flow = await ref
          .read(gaugeRepositoryProvider)
          .flowOn(run.stationId!, DateTime.now());
    } catch (_) {
      // The banner still helps without a flow.
    }
  }
  return PutInCheckIn(run, flow: flow);
});

/// Runs the paddler said "Not now" to, for this session.
final dismissedCheckInsProvider = StateProvider<Set<String>>((ref) => {});

const _locationPromptKey = 'location_prompt_dismissed';

/// Whether the paddler has turned down the "turn on location" card.
final locationPromptDismissedProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_locationPromptKey) ?? false;
});

Future<void> dismissLocationPrompt(WidgetRef ref) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_locationPromptKey, true);
  ref.invalidate(locationPromptDismissedProvider);
}
