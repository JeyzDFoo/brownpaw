import 'package:flutter/widgets.dart';

import '../../domain/offline_map_plan.dart';
import 'offline_map_store_stub.dart'
    if (dart.library.io) 'offline_map_store_io.dart'
    as impl;

/// What's on the device.
class OfflineMapStatus {
  const OfflineMapStatus({this.tiles = 0, this.bytes = 0, this.savedAt});

  final int tiles;
  final int bytes;
  final DateTime? savedAt;

  bool get isEmpty => tiles == 0;
}

/// Map tiles saved on the device for use with no signal. Phones and
/// tablets only; the web app keeps tiles you've viewed in its service
/// worker instead.
abstract class OfflineMapStore {
  factory OfflineMapStore() => impl.createStore();

  bool get supported;

  /// Call once before [localTile]; finds the folder.
  Future<void> open();

  Future<OfflineMapStatus> status();

  /// Downloads [tiles] from [urlTemplate] ({z}/{x}/{y}), skipping ones
  /// already saved, and emits progress from 0 to 1.
  Stream<double> download(List<TileId> tiles, String urlTemplate);

  Future<void> delete();

  /// The saved tile, or null to fetch it from the network.
  ImageProvider? localTile(int z, int x, int y);
}
