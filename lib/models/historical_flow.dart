import 'package:cloud_firestore/cloud_firestore.dart';
import 'daily_mean.dart';

/// Model for historical flow data aggregating daily mean readings
class HistoricalFlow {
  final List<DailyMean> readings;

  const HistoricalFlow({required this.readings});

  /// Fetch historical data from Firestore for a given station and date range
  /// [stationId] should be in format like "environment_canada_08GA072" or "Provider.ENVIRONMENT_CANADA_08GA072"
  /// [days] is how many days of history to fetch (default: 30)
  static Future<HistoricalFlow> fromFirestore({
    required String stationId,
    int days = 30,
  }) async {
    try {
      // Normalize the station ID format
      final stationPath = _normalizeStationId(stationId);

      // Calculate date range
      final endDate = DateTime.now();
      final startDate = endDate.subtract(Duration(days: days));

      // Get the years we need to query
      final years = <int>{};
      for (
        var date = startDate;
        date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
        date = date.add(const Duration(days: 1))
      ) {
        years.add(date.year);
      }

      final dailyMeans = <DailyMean>[];

      // Fetch data from readings/{year} documents
      for (final year in years) {
        final doc = await FirebaseFirestore.instance
            .collection('station_data')
            .doc(stationPath)
            .collection('readings')
            .doc(year.toString())
            .get();

        if (!doc.exists) continue;

        final data = doc.data();
        final dailyReadings = data?['daily_readings'] as Map<String, dynamic>?;

        if (dailyReadings == null) continue;

        // Extract provider and station_id from the parent document
        final parts = stationPath.split('.');
        String provider = 'environment_canada';
        String stationIdPart = stationPath;

        if (parts.length == 2) {
          final enumAndStation = parts[1].split('_');
          if (enumAndStation.length >= 2) {
            provider = enumAndStation
                .take(enumAndStation.length - 1)
                .join('_')
                .toLowerCase();
            stationIdPart = enumAndStation.last;
          }
        }

        // Convert each date entry to DailyMean
        dailyReadings.forEach((dateStr, reading) {
          final readingMap = reading as Map<String, dynamic>;
          final date = DateTime.parse(dateStr);

          // Filter by date range
          if (date.isAfter(startDate.subtract(const Duration(days: 1))) &&
              date.isBefore(endDate.add(const Duration(days: 1)))) {
            final mean = DailyMean(
              provider: provider,
              stationId: stationIdPart,
              date: dateStr,
              level: readingMap['mean_level'] as double?,
              discharge: readingMap['mean_discharge'] as double?,
              levelUnit: 'm',
              dischargeUnit: 'm³/s',
            );
            dailyMeans.add(mean);
          }
        });
      }

      // Sort by date (oldest to newest)
      dailyMeans.sort((a, b) => a.dateTime.compareTo(b.dateTime));

      return HistoricalFlow(readings: dailyMeans);
    } catch (e) {
      print('Error fetching historical flow for $stationId: $e');
      return const HistoricalFlow(readings: []);
    }
  }

  /// Normalize station ID format for Firestore queries
  static String _normalizeStationId(String stationId) {
    // If already in Provider.ENUM_STATION format, return as-is
    if (stationId.startsWith('Provider.')) {
      return stationId;
    }

    // If in environment_canada_08AB001 format, convert to Provider.ENVIRONMENT_CANADA_08AB001
    if (stationId.contains('_')) {
      final parts = stationId.split('_');
      if (parts.length >= 2) {
        final provider = parts.take(parts.length - 1).join('_').toUpperCase();
        final station = parts.last;
        return 'Provider.${provider}_$station';
      }
    }

    return stationId;
  }

  /// Get the most recent reading
  DailyMean? get latestReading => readings.isEmpty ? null : readings.last;

  /// Get the oldest reading
  DailyMean? get oldestReading => readings.isEmpty ? null : readings.first;

  /// Get readings with discharge data
  List<DailyMean> get dischargeReadings =>
      readings.where((r) => r.discharge != null).toList();

  /// Get readings with level data
  List<DailyMean> get levelReadings =>
      readings.where((r) => r.level != null).toList();

  /// Calculate average discharge over the period
  double? get averageDischarge {
    final discharges = readings
        .map((r) => r.discharge)
        .where((d) => d != null)
        .map((d) => d!)
        .toList();

    if (discharges.isEmpty) return null;

    return discharges.reduce((a, b) => a + b) / discharges.length;
  }

  /// Calculate average level over the period
  double? get averageLevel {
    final levels = readings
        .map((r) => r.level)
        .where((l) => l != null)
        .map((l) => l!)
        .toList();

    if (levels.isEmpty) return null;

    return levels.reduce((a, b) => a + b) / levels.length;
  }

  /// Get minimum discharge in the period
  double? get minDischarge {
    final discharges = readings
        .map((r) => r.discharge)
        .where((d) => d != null)
        .map((d) => d!)
        .toList();

    if (discharges.isEmpty) return null;

    return discharges.reduce((a, b) => a < b ? a : b);
  }

  /// Get maximum discharge in the period
  double? get maxDischarge {
    final discharges = readings
        .map((r) => r.discharge)
        .where((d) => d != null)
        .map((d) => d!)
        .toList();

    if (discharges.isEmpty) return null;

    return discharges.reduce((a, b) => a > b ? a : b);
  }

  /// Get minimum level in the period
  double? get minLevel {
    final levels = readings
        .map((r) => r.level)
        .where((l) => l != null)
        .map((l) => l!)
        .toList();

    if (levels.isEmpty) return null;

    return levels.reduce((a, b) => a < b ? a : b);
  }

  /// Get maximum level in the period
  double? get maxLevel {
    final levels = readings
        .map((r) => r.level)
        .where((l) => l != null)
        .map((l) => l!)
        .toList();

    if (levels.isEmpty) return null;

    return levels.reduce((a, b) => a > b ? a : b);
  }

  /// Get date range string
  String? get dateRange {
    if (readings.isEmpty) return null;

    final oldest = oldestReading?.date;
    final latest = latestReading?.date;

    if (oldest == null || latest == null) return null;

    return '$oldest to $latest';
  }

  @override
  String toString() {
    return 'HistoricalFlow(readings: ${readings.length}, '
        'dateRange: $dateRange, avgDischarge: $averageDischarge)';
  }
}
