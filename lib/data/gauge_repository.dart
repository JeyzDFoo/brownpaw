import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../domain/flow_lookup.dart';
import '../models/realtime_flow.dart';

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

/// Reads live gauge data. The Cloud Function writes each station's recent
/// hourly readings to `station_current/{provider}_{stationCode}`.
class GaugeRepository {
  GaugeRepository(this._firestore);

  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> _doc(String stationId) =>
      _firestore.collection('station_current').doc(docIdFor(stationId));

  /// Live readings for [stationId]. Emits null when there's no data.
  Stream<StationRealtimeFlow?> watchCurrent(String stationId) {
    if (stationId.isEmpty) return Stream.value(null);
    final docId = docIdFor(stationId);
    return _doc(stationId).snapshots().map((doc) => _parse(docId, doc.data()));
  }

  /// Readings for [stationId], read once. Null when there's no data.
  Future<StationRealtimeFlow?> getCurrent(String stationId) async {
    if (stationId.isEmpty) return null;
    try {
      final doc = await _doc(stationId).get();
      return _parse(docIdFor(stationId), doc.data());
    } catch (e) {
      debugPrint('GaugeRepository.getCurrent($stationId) failed: $e');
      return null;
    }
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
        if (isToday && current.discharge != null) return current.discharge;
        final flow = flowNearMidday(current.readings, day);
        if (flow != null) return flow;
      }
    }

    try {
      for (final year in {day.year, day.year - 1}) {
        final doc = await _firestore
            .collection('station_data')
            .doc(historyDocIdFor(stationId))
            .collection('readings')
            .doc('$year')
            .get();
        final daily = doc.data()?['daily_readings'];
        if (daily is Map<String, dynamic>) {
          final flow = dailyMeanOnOrBefore(daily, day);
          if (flow != null) return flow;
        }
      }
    } catch (e) {
      debugPrint('GaugeRepository.flowOn($stationId) failed: $e');
    }
    return null;
  }

  static StationRealtimeFlow? _parse(String docId, Map<String, dynamic>? data) {
    final csv = data?['hourly_readings_csv'] as String?;
    if (csv == null || csv.isEmpty) return null;
    final flow = RealtimeFlow.fromCSV(csv);
    if (flow.readings.isEmpty) return null;
    return StationRealtimeFlow(stationId: docId, flow: flow);
  }

  /// Maps the station ids stored on runs to `station_current` document ids.
  ///
  /// - Already a document id (lower case with underscores): unchanged.
  /// - `Provider.ENVIRONMENT_CANADA_08AB001`: prefix dropped, lower-cased.
  /// - A bare Environment Canada code such as `08HD006`:
  ///   `environment_canada_08HD006`.
  /// - Anything else: unchanged.
  static String docIdFor(String stationId) {
    if (stationId.contains('_') && stationId == stationId.toLowerCase()) {
      return stationId;
    }
    if (stationId.startsWith('Provider.')) {
      return stationId.substring('Provider.'.length).toLowerCase();
    }
    if (RegExp(r'^\d{2}[A-Z]{2}\d{3}$').hasMatch(stationId)) {
      return 'environment_canada_$stationId';
    }
    return stationId;
  }

  /// Maps a run's station id to its `station_data` document id, which uses
  /// the form `Provider.ENVIRONMENT_CANADA_08GA043`.
  static String historyDocIdFor(String stationId) {
    if (stationId.startsWith('Provider.')) return stationId;
    if (stationId.contains('_')) {
      final parts = stationId.split('_');
      final provider = parts.take(parts.length - 1).join('_').toUpperCase();
      return 'Provider.${provider}_${parts.last}';
    }
    return 'Provider.ENVIRONMENT_CANADA_$stationId';
  }
}
