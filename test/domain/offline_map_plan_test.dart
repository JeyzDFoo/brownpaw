import 'package:brownpaw/domain/offline_map_plan.dart';
import 'package:brownpaw/models/river_run.dart';
import 'package:brownpaw/providers/offline_map_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const tamihi = (lat: 49.07, lon: -121.83);
  const cheakamus = (lat: 49.93, lon: -123.15);

  test('tile maths matches the web-map scheme', () {
    // Vancouver at zoom 10 is tile 161/350 (checked against the OSM formula).
    expect(lonToTileX(-123.12, 10), 161);
    expect(latToTileY(49.28, 10), 350);
  });

  test('covers the region, then close-ups around runs', () {
    final tiles = planOfflineTiles(points: [tamihi, cheakamus]).toSet();
    expect(tiles.where((t) => t.z == 12), isNotEmpty);
    for (final p in [tamihi, cheakamus]) {
      final close = (z: 15, x: lonToTileX(p.lon, 15), y: latToTileY(p.lat, 15));
      expect(tiles, contains(close));
    }
  });

  test('stays within the size budget', () {
    final points = [
      for (var i = 0; i < 80; i++)
        (lat: 49.0 + i * 0.015, lon: -123.5 + i * 0.03),
    ];
    final tiles = planOfflineTiles(points: points, maxTiles: 4000);
    expect(tiles.length, lessThanOrEqualTo(4000));
    expect(tiles.toSet().length, tiles.length);
  });

  test('ignores runs outside the region', () {
    final inside = planOfflineTiles(points: const []).length;
    final withFarAway = planOfflineTiles(
      points: const [(lat: 51.2, lon: -115.6)],
    ).length;
    expect(withFarAway, inside);
  });

  test('runPoints takes put-ins, take-outs and pins', () {
    final run = RiverRun(
      riverId: 'x',
      name: 'X',
      river: 'X',
      province: 'BC',
      difficultyClass: 'III',
      putInCoordinates: const {'latitude': 49.1, 'longitude': -121.9},
      takeOutCoordinates: const {'latitude': 49.08, 'longitude': -121.95},
    );
    expect(runPoints([run]), [
      (lat: 49.1, lon: -121.9),
      (lat: 49.08, lon: -121.95),
    ]);
  });
}
