import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data' show BytesBuilder;

import 'package:flutter/painting.dart';
import 'package:path_provider/path_provider.dart';

import '../../domain/offline_map_plan.dart';
import 'offline_map_store.dart';

OfflineMapStore createStore() => _FileStore();

/// Tiles in `<app support>/offline_map/{z}/{x}/{y}.png`, with a small
/// `meta.json` recording when and how much.
class _FileStore implements OfflineMapStore {
  Directory? _dir;

  @override
  bool get supported => true;

  @override
  Future<void> open() async {
    _dir ??= Directory(
      '${(await getApplicationSupportDirectory()).path}/offline_map',
    );
  }

  Future<Directory> get _root async {
    await open();
    return _dir!;
  }

  File _meta(Directory root) => File('${root.path}/meta.json');

  @override
  Future<OfflineMapStatus> status() async {
    final meta = _meta(await _root);
    if (!meta.existsSync()) return const OfflineMapStatus();
    try {
      final data = jsonDecode(await meta.readAsString()) as Map;
      return OfflineMapStatus(
        tiles: data['tiles'] as int? ?? 0,
        bytes: data['bytes'] as int? ?? 0,
        savedAt: DateTime.tryParse(data['savedAt'] as String? ?? ''),
      );
    } catch (_) {
      return const OfflineMapStatus();
    }
  }

  @override
  Stream<double> download(List<TileId> tiles, String urlTemplate) async* {
    final root = await _root;
    final client = HttpClient()..userAgent = 'Brownpaw (offline map)';
    var done = 0, bytes = 0, saved = 0;
    try {
      // A few at a time: quick, without hammering the tile server.
      const batch = 6;
      for (var i = 0; i < tiles.length; i += batch) {
        final chunk = tiles.skip(i).take(batch);
        final sizes = await Future.wait([
          for (final t in chunk) _fetch(client, root, t, urlTemplate),
        ]);
        for (final size in sizes) {
          if (size > 0) {
            bytes += size;
            saved++;
          }
        }
        done += chunk.length;
        yield done / tiles.length;
      }
    } finally {
      client.close();
      await _meta(root).writeAsString(
        jsonEncode({
          'tiles': saved,
          'bytes': bytes,
          'savedAt': DateTime.now().toIso8601String(),
        }),
      );
    }
  }

  /// Saves one tile and returns its size; 0 when it couldn't be fetched.
  Future<int> _fetch(
    HttpClient client,
    Directory root,
    TileId t,
    String template,
  ) async {
    final file = File('${root.path}/${t.z}/${t.x}/${t.y}.png');
    if (file.existsSync()) return file.lengthSync();
    try {
      final url = template
          .replaceAll('{z}', '${t.z}')
          .replaceAll('{x}', '${t.x}')
          .replaceAll('{y}', '${t.y}');
      final request = await client.getUrl(Uri.parse(url));
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode != 200) {
        await response.drain<void>();
        return 0;
      }
      final data = await consolidate(response);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data, flush: false);
      return data.length;
    } catch (_) {
      return 0;
    }
  }

  static Future<List<int>> consolidate(HttpClientResponse response) async {
    final out = BytesBuilder(copy: false);
    await for (final chunk in response) {
      out.add(chunk);
    }
    return out.takeBytes();
  }

  @override
  Future<void> delete() async {
    final root = await _root;
    if (root.existsSync()) await root.delete(recursive: true);
  }

  @override
  ImageProvider? localTile(int z, int x, int y) {
    final dir = _dir;
    if (dir == null) return null;
    final file = File('${dir.path}/$z/$x/$y.png');
    return file.existsSync() ? FileImage(file) : null;
  }
}
