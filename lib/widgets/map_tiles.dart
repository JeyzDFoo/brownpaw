import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

/// OpenStreetMap tiles, shared by every map in the app.
abstract final class MapTiles {
  /// Turned off in widget tests, which have no network.
  static bool enabled = true;

  /// Mutes the tiles' colours so the map sits with the app's silt-green
  /// palette and the run pins stand out. Roads and labels stay readable.
  static const _muted = ColorFilter.matrix([
    0.55, 0.38, 0.07, 0, 6, //
    0.20, 0.72, 0.08, 0, 8, //
    0.20, 0.38, 0.42, 0, 4, //
    0, 0, 0, 1, 0, //
  ]);

  static Widget layer() => enabled
      ? TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.brownpaw.app',
          tileBuilder: (context, tile, _) =>
              ColorFiltered(colorFilter: _muted, child: tile),
        )
      : const SizedBox.shrink();
}
