import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// OpenStreetMap tiles, shared by every map in the app.
abstract final class MapTiles {
  /// Turned off in widget tests, which have no network.
  static bool enabled = true;

  static Widget layer() => enabled
      ? TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.brownpaw.app',
        )
      : const SizedBox.shrink();
}
