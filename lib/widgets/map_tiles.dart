import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';

import '../data/offline_map/offline_map_store.dart';

/// Map tiles, shared by every map in the app.
///
/// By default OpenStreetMap's free tiles, which may be viewed and cached
/// but not downloaded in bulk. Building with a provider that allows offline
/// downloads turns on "Download offline map" (see docs/offline-map.md):
///
///     flutter build ... \
///       --dart-define=MAP_TILE_URL='https://tiles.stadiamaps.com/tiles/outdoors/{z}/{x}/{y}.png?api_key=KEY' \
///       --dart-define=MAP_TILE_ATTRIBUTION='© Stadia Maps © OpenMapTiles © OpenStreetMap contributors'
abstract final class MapTiles {
  /// Turned off in widget tests, which have no network.
  static bool enabled = true;

  static const _configuredUrl = String.fromEnvironment('MAP_TILE_URL');

  static String get urlTemplate => _configuredUrl.isEmpty
      ? 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'
      : _configuredUrl;

  static String get attribution {
    const configured = String.fromEnvironment('MAP_TILE_ATTRIBUTION');
    return configured.isNotEmpty ? configured : '© OpenStreetMap contributors';
  }

  /// Whether the tile provider allows downloading an area for offline use.
  static bool get offlineDownloadAllowed => _configuredUrl.isNotEmpty;

  /// Saved tiles, used before the network when present.
  static final OfflineMapStore store = OfflineMapStore();

  static Widget layer() => enabled
      ? TileLayer(
          urlTemplate: urlTemplate,
          userAgentPackageName: 'com.brownpaw.app',
          tileProvider: _OfflineFirstTileProvider(store),
        )
      : const SizedBox.shrink();

  /// The credit line the tile providers require, for the corner of a map.
  static Widget credit() => enabled
      ? SimpleAttributionWidget(source: Text(attribution))
      : const SizedBox.shrink();
}

/// Saved tiles first (an offline download), then the network as usual.
class _OfflineFirstTileProvider extends NetworkTileProvider {
  _OfflineFirstTileProvider(this.store);

  final OfflineMapStore store;

  @override
  ImageProvider getImageWithCancelLoadingSupport(
    TileCoordinates coordinates,
    TileLayer options,
    Future<void> cancelLoading,
  ) =>
      store.localTile(coordinates.z, coordinates.x, coordinates.y) ??
      super.getImageWithCancelLoadingSupport(
        coordinates,
        options,
        cancelLoading,
      );
}
