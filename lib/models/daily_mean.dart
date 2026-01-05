import 'package:cloud_firestore/cloud_firestore.dart';

/// Historical daily mean water level data for long-term analysis.
///
/// This is used for historical data (daily averages) as opposed to real-time
/// readings in StationLevel.
///
/// Collection path: stations/{provider}_{station_id}/daily_means
/// Document ID: {YYYY-MM-DD} (e.g., "2024-12-31")
class DailyMean {
  /// Data provider (e.g., "environment_canada", "usgs")
  final String provider;

  /// Provider's station identifier
  final String stationId;

  /// Date in YYYY-MM-DD format
  final String date;

  /// Daily mean water level in meters
  final double? level;

  /// Daily mean discharge in m³/s
  final double? discharge;

  /// Unit for level (standardized to "m")
  final String levelUnit;

  /// Unit for discharge (standardized to "m³/s")
  final String dischargeUnit;

  /// Provider-specific symbols, flags, etc.
  final Map<String, dynamic>? rawData;

  const DailyMean({
    required this.provider,
    required this.stationId,
    required this.date,
    this.level,
    this.discharge,
    this.levelUnit = 'm',
    this.dischargeUnit = 'm³/s',
    this.rawData,
  });

  /// Create from Firestore document
  factory DailyMean.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DailyMean.fromMap(data);
  }

  /// Create from Map
  factory DailyMean.fromMap(Map<String, dynamic> data) {
    return DailyMean(
      provider: data['provider'] as String,
      stationId: data['station_id'] as String,
      date: data['date'] as String,
      level: data['level'] as double?,
      discharge: data['discharge'] as double?,
      levelUnit: data['level_unit'] as String? ?? 'm',
      dischargeUnit: data['discharge_unit'] as String? ?? 'm³/s',
      rawData: data['raw_data'] as Map<String, dynamic>?,
    );
  }

  /// Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'provider': provider,
      'station_id': stationId,
      'date': date,
      'level': level,
      'discharge': discharge,
      'level_unit': levelUnit,
      'discharge_unit': dischargeUnit,
      'raw_data': rawData,
    };
  }

  /// Get the document ID (just the date)
  String get documentId => date;

  /// Get DateTime from the date string
  DateTime get dateTime => DateTime.parse(date);

  /// Get the parent station document path
  String get stationPath => '${provider}_$stationId';

  @override
  String toString() {
    return 'DailyMean(date: $date, level: $level $levelUnit, '
        'discharge: $discharge $dischargeUnit)';
  }
}
