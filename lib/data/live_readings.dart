import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/realtime_flow.dart';

/// Recent readings fetched live from each gauge's own source (Environment
/// Canada, Metro Vancouver, Flowworks) through the app's `/api/live`
/// endpoint (functions/live.py), which every platform can reach (browsers
/// can't call some sources directly).
///
/// Anything within the last 30 days comes from here first; the Firestore
/// copy the Cloud Function keeps is the fallback (offline, source down)
/// and the base the live readings are laid on, so only the missing hours
/// are fetched.
class LiveReadings {
  LiveReadings({http.Client? client, Uri? endpoint})
    : _client = client ?? http.Client(),
      _endpoint = endpoint ?? defaultEndpoint;

  final http.Client _client;
  final Uri _endpoint;

  /// Same-origin on the web (Firebase Hosting rewrite), the hosted app's
  /// domain elsewhere. Override with --dart-define=LIVE_API=...
  static Uri get defaultEndpoint {
    const configured = String.fromEnvironment('LIVE_API');
    if (configured.isNotEmpty) return Uri.parse(configured);
    if (kIsWeb) return Uri.base.resolve('/api/live');
    return Uri.parse('https://brownclaw.web.app/api/live');
  }

  /// How long a fetch is reused: the sources update every 5 to 15 minutes.
  static const fresh = Duration(minutes: 5);

  final _cache =
      <String, ({DateTime at, int hours, List<FlowReading> readings})>{};
  final _inFlight = <String, Future<List<FlowReading>?>>{};

  /// Readings for [stationId] (a `station_current` id) covering at least
  /// the last [hours], oldest first; null when the source can't be reached.
  Future<List<FlowReading>?> fetch(
    String stationId,
    int hours, {
    DateTime? now,
  }) {
    final bucket = hoursBucket(hours);
    final cached = _cache[stationId];
    final t = now ?? DateTime.now();
    if (cached != null &&
        cached.hours >= bucket &&
        t.difference(cached.at) < fresh) {
      return Future.value(cached.readings);
    }
    final key = '$stationId/$bucket';
    return _inFlight[key] ??= _get(stationId, bucket, t).whenComplete(() {
      // A block, not `=>`: whenComplete waits on a returned future, and
      // remove() returns this very one.
      _inFlight.remove(key);
    });
  }

  Future<List<FlowReading>?> _get(
    String stationId,
    int hours,
    DateTime t,
  ) async {
    try {
      final uri = _endpoint.replace(
        queryParameters: {'station': stationId, 'hours': '$hours'},
      );
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return null;
      final readings = RealtimeFlow.fromCSV(response.body).readings;
      _cache[stationId] = (at: t, hours: hours, readings: readings);
      return readings;
    } catch (e) {
      debugPrint('Live readings for $stationId failed: $e');
      return null;
    }
  }
}

/// Request sizes, so responses are shared through the CDN.
const _buckets = [3, 6, 12, 24, 72, 168, 336, 720];

int hoursBucket(int hours) =>
    _buckets.firstWhere((b) => b >= hours, orElse: () => _buckets.last);

/// How many hours of live readings the stored copy is missing (plus an hour
/// of overlap), or the full 30 days when there's no stored copy.
int hoursMissing(List<FlowReading> stored, DateTime now) {
  if (stored.isEmpty) return 720;
  final gap = now.difference(stored.last.timestamp).inMinutes / 60;
  return gap.ceil().clamp(0, 719) + 1;
}

/// [stored] up to where [live] begins, then [live]: the live source wins
/// wherever it has data. Last 30 days only, oldest first.
List<FlowReading> mergeLive(
  List<FlowReading> stored,
  List<FlowReading>? live,
  DateTime now,
) {
  final from = now.subtract(const Duration(days: 30));
  if (live == null || live.isEmpty) {
    return [
      for (final r in stored)
        if (!r.timestamp.isBefore(from)) r,
    ];
  }
  final liveStart = live.first.timestamp;
  return [
    for (final r in stored)
      if (!r.timestamp.isBefore(from) && r.timestamp.isBefore(liveStart)) r,
    for (final r in live)
      if (!r.timestamp.isBefore(from)) r,
  ];
}
