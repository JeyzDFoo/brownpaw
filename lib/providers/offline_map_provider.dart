import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/offline_map/offline_map_store.dart';
import '../domain/offline_map_plan.dart';
import '../models/river_run.dart';
import '../widgets/map_tiles.dart';
import 'river_runs_provider.dart';

class OfflineMapState {
  const OfflineMapState({
    this.status = const OfflineMapStatus(),
    this.progress,
    this.error,
  });

  final OfflineMapStatus status;

  /// 0 to 1 while downloading, else null.
  final double? progress;
  final String? error;

  bool get downloading => progress != null;
}

/// The downloadable Lower Mainland map: region overview plus close-ups
/// around every run, within the tile provider's per-device limit.
final offlineMapProvider =
    StateNotifierProvider<OfflineMapNotifier, OfflineMapState>(
      (ref) => OfflineMapNotifier(MapTiles.store, ref),
    );

class OfflineMapNotifier extends StateNotifier<OfflineMapState> {
  OfflineMapNotifier(this._store, this._ref) : super(const OfflineMapState()) {
    _refresh();
  }

  final OfflineMapStore _store;
  final Ref _ref;
  StreamSubscription<double>? _download;

  Future<void> _refresh() async {
    try {
      final status = await _store.status();
      if (mounted) state = OfflineMapState(status: status);
    } catch (e) {
      debugPrint('Offline map status: $e');
    }
  }

  /// The tiles a download would fetch, from the runs in the guide.
  List<TileId> plan() {
    final runs = _ref.read(riverRunsStreamProvider).valueOrNull ?? const [];
    return planOfflineTiles(points: runPoints(runs));
  }

  void download() {
    if (state.downloading) return;
    final tiles = plan();
    state = OfflineMapState(status: state.status, progress: 0);
    _download = _store
        .download(tiles, MapTiles.urlTemplate)
        .listen(
          (p) => state = OfflineMapState(status: state.status, progress: p),
          onError: (Object e) => state = OfflineMapState(
            status: state.status,
            error: "Couldn't finish the download. Try again with signal.",
          ),
          onDone: _refresh,
        );
  }

  Future<void> cancel() async {
    await _download?.cancel();
    _download = null;
    await _refresh();
  }

  Future<void> delete() async {
    await cancel();
    await _store.delete();
    await _refresh();
  }

  @override
  void dispose() {
    _download?.cancel();
    super.dispose();
  }
}

/// Put-ins, take-outs and pins of runs, for close-up tiles.
List<({double lat, double lon})> runPoints(List<RiverRun> runs) => [
  for (final run in runs)
    for (final c in [
      run.putInCoordinates,
      run.takeOutCoordinates,
      run.coordinates,
    ])
      if (c != null && c['latitude'] != null && c['longitude'] != null)
        (lat: c['latitude']!, lon: c['longitude']!),
];
