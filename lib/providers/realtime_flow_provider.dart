import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/gauge_repository.dart';
import '../data/repositories.dart';

export '../data/gauge_repository.dart' show StationRealtimeFlow;

/// Real-time flow for a station, read once.
final realtimeFlowProvider =
    FutureProvider.family<StationRealtimeFlow?, String>(
      (ref, stationId) =>
          ref.watch(gaugeRepositoryProvider).getCurrent(stationId),
    );

/// Real-time flow for a station, updating live.
final realtimeFlowStreamProvider =
    StreamProvider.family<StationRealtimeFlow?, String>(
      (ref, stationId) =>
          ref.watch(gaugeRepositoryProvider).watchCurrent(stationId),
    );
