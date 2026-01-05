import 'package:cloud_firestore/cloud_firestore.dart';

/// Current real-time water level reading for a monitoring station.
///
/// Collection: station_levels
/// Document ID: {provider}_{station_id} (e.g., "environment_canada_08GA072")
class StationLevel {
  /// Data provider (e.g., "environment_canada", "usgs")
  final String provider;

  /// Provider's station identifier
  final String stationId;

  /// Water level in meters
  final double? level;

  /// Discharge/flow in m³/s
  final double? discharge;

  /// When the reading was taken
  final DateTime timestamp;

  /// Trend: "rising", "falling", or "stable"
  final String trend;

  /// Unit for level (standardized to "m")
  final String levelUnit;

  /// Unit for discharge (standardized to "m³/s")
  final String dischargeUnit;

  /// When we last fetched this data
  final DateTime lastUpdated;

  /// Original provider data (preserved for debugging)
  final Map<String, dynamic>? rawData;

  const StationLevel({
    required this.provider,
    required this.stationId,
    this.level,
    this.discharge,
    required this.timestamp,
    required this.trend,
    this.levelUnit = 'm',
    this.dischargeUnit = 'm³/s',
    required this.lastUpdated,
    this.rawData,
  });

  /// Create from Firestore document
  factory StationLevel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StationLevel.fromMap(data);
  }

  /// Create from Map
  factory StationLevel.fromMap(Map<String, dynamic> data) {
    return StationLevel(
      provider: data['provider'] as String,
      stationId: data['station_id'] as String,
      level: data['level'] as double?,
      discharge: data['discharge'] as double?,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      trend: data['trend'] as String? ?? 'stable',
      levelUnit: data['level_unit'] as String? ?? 'm',
      dischargeUnit: data['discharge_unit'] as String? ?? 'm³/s',
      lastUpdated: (data['last_updated'] as Timestamp).toDate(),
      rawData: data['raw_data'] as Map<String, dynamic>?,
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'provider': provider,
      'station_id': stationId,
      'level': level,
      'discharge': discharge,
      'timestamp': Timestamp.fromDate(timestamp),
      'trend': trend,
      'level_unit': levelUnit,
      'discharge_unit': dischargeUnit,
      'last_updated': Timestamp.fromDate(lastUpdated),
      'raw_data': rawData,
    };
  }

  /// Get the document ID for this station level
  String get documentId => '${provider}_$stationId';

  @override
  String toString() {
    return 'StationLevel(provider: $provider, stationId: $stationId, '
        'level: $level $levelUnit, discharge: $discharge $dischargeUnit, '
        'trend: $trend, timestamp: $timestamp)';
  }
}
