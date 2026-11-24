import 'dart:math' as math;

/// One map tile, in the usual web-map scheme.
typedef TileId = ({int z, int x, int y});

/// A latitude/longitude box.
typedef GeoBox = ({double south, double west, double north, double east});

/// The Lower Mainland and Sea to Sky: Squamish and Whistler to the US border,
/// the Strait to Hope.
const GeoBox lowerMainland = (
  south: 48.95,
  west: -123.6,
  north: 50.2,
  east: -121.2,
);

/// What one download should hold: the whole region at overview zooms,
/// then closer and closer around each run's put-in, take-out and pin,
/// until [maxTiles] (a size budget: tile providers that allow offline use
/// cap storage per device: Stadia at 100 MB, so 3,500 tiles of about
/// 25 KB leaves room).
List<TileId> planOfflineTiles({
  required List<({double lat, double lon})> points,
  GeoBox region = lowerMainland,
  int maxTiles = 3500,
}) {
  final tiles = <TileId>{};
  bool addAll(Iterable<TileId> more) {
    for (final t in more) {
      if (tiles.length >= maxTiles) return false;
      tiles.add(t);
    }
    return true;
  }

  for (var z = 6; z <= 12; z++) {
    if (!addAll(tilesInBox(region, z))) return tiles.toList();
  }
  // Closer zooms only near runs, widest first so every run gets some.
  const rings = [(z: 13, km: 6.0), (z: 14, km: 3.0), (z: 15, km: 1.5)];
  for (final ring in rings) {
    for (final p in points) {
      if (!_inside(region, p)) continue;
      if (!addAll(tilesInBox(_around(p, ring.km), ring.z))) {
        return tiles.toList();
      }
    }
  }
  return tiles.toList();
}

/// Every tile at zoom [z] that overlaps [box].
Iterable<TileId> tilesInBox(GeoBox box, int z) sync* {
  final x0 = lonToTileX(box.west, z), x1 = lonToTileX(box.east, z);
  final y0 = latToTileY(box.north, z), y1 = latToTileY(box.south, z);
  for (var x = x0; x <= x1; x++) {
    for (var y = y0; y <= y1; y++) {
      yield (z: z, x: x, y: y);
    }
  }
}

int lonToTileX(double lon, int z) =>
    ((lon + 180) / 360 * (1 << z)).floor().clamp(0, (1 << z) - 1);

int latToTileY(double lat, int z) {
  final r = lat * math.pi / 180;
  final y = (1 - math.log(math.tan(r) + 1 / math.cos(r)) / math.pi) / 2;
  return (y * (1 << z)).floor().clamp(0, (1 << z) - 1);
}

bool _inside(GeoBox b, ({double lat, double lon}) p) =>
    p.lat >= b.south && p.lat <= b.north && p.lon >= b.west && p.lon <= b.east;

GeoBox _around(({double lat, double lon}) p, double km) {
  final dLat = km / 111.0;
  final dLon = km / (111.0 * math.cos(p.lat * math.pi / 180));
  return (
    south: p.lat - dLat,
    west: p.lon - dLon,
    north: p.lat + dLat,
    east: p.lon + dLon,
  );
}
