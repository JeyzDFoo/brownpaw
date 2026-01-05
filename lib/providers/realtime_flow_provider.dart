import 'package:brownpaw/models/realtime_flow.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Wrapper class for station-specific realtime flow data
class StationRealtimeFlow {
  final String stationId;
  final RealtimeFlow flow;

  const StationRealtimeFlow({required this.stationId, required this.flow});

  /// Convenience getters
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

/// Provider for fetching real-time flow data from station_current collection
final realtimeFlowProvider =
    FutureProvider.family<StationRealtimeFlow?, String>((ref, stationId) async {
      if (stationId.isEmpty) return null;

      try {
        final normalizedId = _normalizeStationId(stationId);

        print('🌊 Fetching real-time flow for: $normalizedId');

        final doc = await FirebaseFirestore.instance
            .collection('station_current')
            .doc(normalizedId)
            .get();

        if (!doc.exists) {
          print('❌ No real-time flow data found for: $normalizedId');
          return null;
        }

        final data = doc.data() as Map<String, dynamic>;
        final csvData = data['hourly_readings_csv'] as String?;

        if (csvData == null || csvData.isEmpty) {
          print('❌ No CSV data found in document');
          return null;
        }

        print('📊 Parsing CSV data (${csvData.length} chars)');

        final flow = RealtimeFlow.fromCSV(csvData);

        if (flow.readings.isEmpty) {
          print('❌ No valid readings parsed from CSV');
          return null;
        }

        print('✅ Parsed ${flow.readings.length} flow readings');
        print('   Latest: ${flow.latestReading?.timestamp}');
        print('   Trend: ${flow.trend}');

        return StationRealtimeFlow(stationId: normalizedId, flow: flow);
      } catch (e) {
        print('❌ Error fetching real-time flow for $stationId: $e');
        return null;
      }
    });

/// Stream provider for real-time flow updates
final realtimeFlowStreamProvider =
    StreamProvider.family<StationRealtimeFlow?, String>((ref, stationId) {
      if (stationId.isEmpty) {
        return Stream.value(null);
      }

      final normalizedId = _normalizeStationId(stationId);

      print('🌊 Setting up real-time flow stream for: $normalizedId');

      return FirebaseFirestore.instance
          .collection('station_current')
          .doc(normalizedId)
          .snapshots()
          .map((doc) {
            if (!doc.exists) return null;

            final data = doc.data() as Map<String, dynamic>?;
            final csvData = data?['hourly_readings_csv'] as String?;

            if (csvData == null || csvData.isEmpty) return null;

            final flow = RealtimeFlow.fromCSV(csvData);

            if (flow.readings.isEmpty) return null;

            return StationRealtimeFlow(stationId: normalizedId, flow: flow);
          });
    });

/// Normalize station ID to match Firestore document ID format
/// station_current collection uses format: environment_canada_08AB001
String _normalizeStationId(String stationId) {
  print('🔍 Normalizing stationId: $stationId');

  // If it's already in the correct format (lowercase with underscores), return as-is
  if (stationId.contains('_') && stationId == stationId.toLowerCase()) {
    print('   ✅ Already in correct format');
    return stationId;
  }

  // If it has Provider. prefix, convert to lowercase underscore format
  // "Provider.ENVIRONMENT_CANADA_08AB001" -> "environment_canada_08ab001"
  if (stationId.startsWith('Provider.')) {
    final withoutPrefix = stationId.substring('Provider.'.length);
    final normalized = withoutPrefix.toLowerCase();
    print('   ✅ Converted from Provider. format: $normalized');
    return normalized;
  }

  // If it's just a station code, assume Environment Canada
  // "08HD006" -> "environment_canada_08hd006"
  if (RegExp(r'^\d{2}[A-Z]{2}\d{3}$').hasMatch(stationId)) {
    final normalized = 'environment_canada_${stationId.toLowerCase()}';
    print('   ✅ Converted from station code: $normalized');
    return normalized;
  }

  // Return as-is if format is unknown
  print('   ⚠️  Unknown format, returning as-is');
  return stationId;
}
