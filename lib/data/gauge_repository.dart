import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/dam_release.dart';
import '../domain/tidal.dart';
import '../domain/flow_lookup.dart';
import '../domain/flow_ranges.dart' show FlowUnit;
import '../domain/gauges.dart';
import '../models/realtime_flow.dart';
import 'live_readings.dart';

/// The latest readings for one gauge station.
class StationRealtimeFlow {
  final String stationId;
  final RealtimeFlow flow;

  const StationRealtimeFlow({required this.stationId, required this.flow});

  FlowReading? get latestReading => flow.latestReading;
  FlowReading? get oldestReading => flow.oldestReading;
  String? get trend => flow.trend;
  List<FlowReading> get readings => flow.readings;

  double? get discharge => latestReading?.discharge;
  double? get level => latestReading?.level;
  DateTime? get timestamp => latestReading?.timestamp;

  @override
  String toString() {
    return 'StationRealtimeFlow(stationId: $stationId, '
        'readings: ${readings.length}, latest: $timestamp, trend: $trend)';
  }
}

/// A station's official name and latest flow, small enough to load for
/// every station at once.
class StationSummary {
  const StationSummary({
    this.name,
    this.flow,
    this.level,
    this.readingTime,
    this.note,
  });

  /// The latest of [live]'s readings, so a list can be sorted on exactly
  /// what its rows show.
  factory StationSummary.fromLive(StationRealtimeFlow live) => StationSummary(
    flow: live.discharge,
    level: live.level,
    readingTime: live.timestamp,
  );

  factory StationSummary.fromMap(Map<String, dynamic> data) {
    final flow = data['flow'];
    final level = data['level'];
    final time = data['readingTime'];
    return StationSummary(
      name: data['name'] is String ? data['name'] as String : null,
      flow: flow is num ? flow.toDouble() : null,
      level: level is num ? level.toDouble() : null,
      readingTime: time is String ? DateTime.tryParse(time) : null,
      note: data['note'] is String ? data['note'] as String : null,
    );
  }

  final String? name;
  final double? flow;

  /// Latest water level in metres, for runs measured on the stick.
  final double? level;
  final DateTime? readingTime;

  /// A line from the source worth showing on the gauge page, such as how
  /// long a dam release takes to reach the run.
  final String? note;
}

/// Reads live gauge data. The Cloud Function writes each station's recent
/// hourly readings to `station_current/{provider}_{stationCode}`.
class GaugeRepository {
  GaugeRepository(this._firestore, {LiveReadings? live})
    : _live = live ?? LiveReadings();

  final FirebaseFirestore _firestore;
  final LiveReadings _live;

  DocumentReference<Map<String, dynamic>> _doc(String stationId) =>
      _firestore.collection('station_current').doc(docIdFor(stationId));

  /// Live readings for [stationId]. Emits null when there's no data.
  Stream<StationRealtimeFlow?> watchCurrent(String stationId) {
    if (stationId.isEmpty) return Stream.value(null);
    final docId = docIdFor(stationId);
    return _doc(stationId).snapshots().map((doc) => _parse(docId, doc.data()));
  }

  /// Readings for [stationId], read once: the stored copy topped up with
  /// live readings from the source. Null when there's neither.
  Future<StationRealtimeFlow?> getCurrent(String stationId) async {
    if (stationId.isEmpty) return null;
    final docId = docIdFor(stationId);
    StationRealtimeFlow? stored;
    try {
      stored = _parse(docId, (await _doc(stationId).get()).data());
    } catch (e) {
      debugPrint('GaugeRepository.getCurrent($stationId) failed: $e');
    }
    return _withLive(docId, stored, DateTime.now());
  }

  /// Live readings for [stationId], updating: the stored copy straight
  /// away (it's on the device, so this works offline), then topped up
  /// from the source, refreshed every few minutes while watched.
  Stream<StationRealtimeFlow?> watchLive(String stationId) {
    if (stationId.isEmpty) return Stream.value(null);
    final docId = docIdFor(stationId);
    late StreamController<StationRealtimeFlow?> controller;
    StreamSubscription<Object?>? sub;
    Timer? timer;
    StationRealtimeFlow? stored;
    var seen = false;

    Future<void> refresh() async {
      final merged = await _withLive(docId, stored, DateTime.now());
      if (!controller.isClosed && (merged != null || seen)) {
        controller.add(merged);
      }
    }

    controller = StreamController<StationRealtimeFlow?>(
      onListen: () {
        sub = _doc(stationId).snapshots().listen(
          (doc) {
            stored = _parse(docId, doc.data());
            seen = true;
            controller.add(stored);
            refresh();
          },
          onError: (Object e) {
            debugPrint('GaugeRepository.watchLive($stationId): $e');
            seen = true;
            refresh();
          },
        );
        timer = Timer.periodic(LiveReadings.fresh, (_) => refresh());
      },
      onCancel: () async {
        timer?.cancel();
        await sub?.cancel();
      },
    );
    return controller.stream;
  }

  /// A dam's published release schedule, updating. Emits null when the
  /// station has none (every gauge that isn't a dam release).
  Stream<ReleaseSchedule?> watchReleaseSchedule(String stationId) {
    if (stationId.isEmpty) return Stream.value(null);
    return _doc(stationId).snapshots().map((doc) {
      final csv = doc.data()?['release_schedule_csv'];
      return csv is String && csv.isNotEmpty
          ? ReleaseSchedule.fromCsv(csv)
          : null;
    });
  }

  /// A tidal spot's current and tide predictions, updating. Emits null
  /// when the station has none.
  Stream<TidalPredictions?> watchTidal(String stationId) {
    if (stationId.isEmpty) return Stream.value(null);
    return _doc(stationId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;
      final p = TidalPredictions.fromDoc(data);
      return p.isEmpty ? null : p;
    });
  }

  Future<StationRealtimeFlow?> _withLive(
    String docId,
    StationRealtimeFlow? stored,
    DateTime now,
  ) async {
    // A dam's schedule is only in the stored copy; there's no live feed.
    // Nor do tidal predictions.
    if (isReleaseGauge(docId) || isTidalGauge(docId)) return stored;
    final base = stored?.readings ?? const <FlowReading>[];
    final live = await _live.fetch(docId, hoursMissing(base, now), now: now);
    final readings = mergeLive(base, live, now);
    if (readings.isEmpty) return stored;
    return StationRealtimeFlow(
      stationId: docId,
      flow: RealtimeFlow(readings: readings),
    );
  }

  /// The flow to record for a descent on [day]: the hourly reading nearest
  /// midday when [day] is within the last 30 days, else the daily mean
  /// (or the closest earlier day's). Null when nothing is available.
  Future<double?> flowOn(
    String stationId,
    DateTime day, {
    DateTime? now,
  }) async {
    if (stationId.isEmpty) return null;
    final today = now ?? DateTime.now();

    if (today.difference(day).inDays <= 30) {
      final current = await getCurrent(stationId);
      final isToday =
          day.year == today.year &&
          day.month == today.month &&
          day.day == today.day;
      if (current != null) {
        // For today, the latest reading is what the paddler saw.
        if (isToday &&
            current.discharge != null &&
            !isReleaseGauge(docIdFor(stationId))) {
          return current.discharge;
        }
        if (!isReleaseGauge(docIdFor(stationId))) {
          final flow = flowNearMidday(current.readings, day);
          if (flow != null) return flow;
        }
      }
      if (isReleaseGauge(docIdFor(stationId))) {
        ReleaseSchedule? schedule;
        if (isToday) {
          try {
            final csv = (await _doc(
              stationId,
            ).get()).data()?['release_schedule_csv'];
            if (csv is String && csv.isNotEmpty) {
              schedule = ReleaseSchedule.fromCsv(csv);
            }
          } catch (e) {
            debugPrint('GaugeRepository.flowOn($stationId) schedule: $e');
          }
        }
        final flow = releaseFlowToRecord(
          readings: current?.readings ?? const [],
          day: day,
          now: today,
          schedule: schedule,
        );
        if (flow != null) return flow;
      }
    }

    try {
      for (final year in {day.year, day.year - 1}) {
        final daily = await _dailyReadings(stationId, year);
        final flow = dailyMeanOnOrBefore(daily, day);
        if (flow != null) return flow;
      }
    } catch (e) {
      debugPrint('GaugeRepository.flowOn($stationId) failed: $e');
    }
    return null;
  }

  /// Every station's summary from `stations/{doc id}`, written by the
  /// realtime Cloud Function: official name and latest flow.
  Stream<Map<String, StationSummary>> watchStations() => _firestore
      .collection('stations')
      .snapshots()
      .map(
        (s) => {for (final d in s.docs) d.id: StationSummary.fromMap(d.data())},
      );

  /// Daily mean flows for the last [days] days, oldest first.
  Future<List<FlowPoint>> dailyFlows(
    String stationId,
    int days, {
    DateTime? now,
    FlowUnit unit = FlowUnit.cms,
  }) async {
    final to = now ?? DateTime.now();
    final from = to.subtract(Duration(days: days));
    final docs = <Map<String, dynamic>>[];
    try {
      docs.addAll(
        await Future.wait([
          for (var year = from.year; year <= to.year; year++)
            _dailyReadings(stationId, year),
        ]),
      );
    } catch (e) {
      debugPrint('GaugeRepository.dailyFlows($stationId) failed: $e');
    }
    return dailySeries(docs, from, to, unit: unit);
  }

  /// One year's `daily_readings` for [stationId], from
  /// `station_data/{doc id}/readings/{year}`.
  Future<Map<String, dynamic>> _dailyReadings(
    String stationId,
    int year,
  ) async {
    final doc = await _firestore
        .collection('station_data')
        .doc(docIdFor(stationId))
        .collection('readings')
        .doc('$year')
        .get();
    final daily = doc.data()?['daily_readings'];
    return daily is Map<String, dynamic> ? daily : const {};
  }

  static StationRealtimeFlow? _parse(String docId, Map<String, dynamic>? data) {
    final csv = data?['hourly_readings_csv'] as String?;
    if (csv == null || csv.isEmpty) return null;
    final flow = RealtimeFlow.fromCSV(csv);
    if (flow.readings.isEmpty) return null;
    return StationRealtimeFlow(stationId: docId, flow: flow);
  }

  /// The one id form for a station: `environment_canada_08MH001` (code in
  /// capitals), `metro_vancouver_capilano`, `flowworks_lynn`. Runs should
  /// already store this (scripts/normalize_station_ids.py); older forms,
  /// `08MH001` and `Provider.ENVIRONMENT_CANADA_08MH001`, still map to it.
  static String docIdFor(String stationId) {
    final ec = _ecCode.firstMatch(stationId);
    if (ec != null &&
        (stationId.length == 7 ||
            stationId.toLowerCase().contains('environment_canada'))) {
      return 'environment_canada_${ec.group(1)!.toUpperCase()}';
    }
    return stationId;
  }

  static final _ecCode = RegExp(r'(?:^|_)(\d{2}[A-Za-z]{2}\d{3})$');
}
