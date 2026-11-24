import 'package:flutter/widgets.dart';

import '../../domain/offline_map_plan.dart';
import 'offline_map_store.dart';

OfflineMapStore createStore() => _NoStore();

class _NoStore implements OfflineMapStore {
  @override
  bool get supported => false;

  @override
  Future<void> open() async {}

  @override
  Future<OfflineMapStatus> status() async => const OfflineMapStatus();

  @override
  Stream<double> download(List<TileId> tiles, String urlTemplate) =>
      const Stream.empty();

  @override
  Future<void> delete() async {}

  @override
  ImageProvider? localTile(int z, int x, int y) => null;
}
