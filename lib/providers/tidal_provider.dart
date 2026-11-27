import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories.dart';
import '../domain/tidal.dart';

/// A tidal spot's predictions by `station_current` id, updating.
final tidalPredictionsProvider =
    StreamProvider.family<TidalPredictions?, String>(
      (ref, stationId) =>
          ref.watch(gaugeRepositoryProvider).watchTidal(stationId),
    );
