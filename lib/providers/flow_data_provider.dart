import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/station_level.dart';
import '../models/daily_mean.dart';

/// Provider for fetching current station level data
final stationLevelProvider = FutureProvider.family<StationLevel?, String>((
  ref,
  stationId,
) async {
  if (stationId.isEmpty) return null;

  try {
    // Convert stationId format if needed
    // From: "Provider.ENVIRONMENT_CANADA_08AB001" or "environment_canada_08AB001"
    // To: "Provider.ENVIRONMENT_CANADA_08AB001" (actual Firestore doc ID)
    final docId = _normalizeStationId(stationId);

    print('Fetching station level for: $docId (original: $stationId)');

    final doc = await FirebaseFirestore.instance
        .collection('station_levels')
        .doc(docId)
        .get();

    if (!doc.exists) {
      print('Station level document not found: $docId');
      return null;
    }

    return StationLevel.fromFirestore(doc);
  } catch (e) {
    print('Error fetching station level for $stationId: $e');
    return null;
  }
});

/// Provider for fetching historical daily mean flow data
/// Returns data for the last N days (default: 30)
final dailyMeansProvider = FutureProvider.family<List<DailyMean>, DailyMeansParams>((
  ref,
  params,
) async {
  if (params.stationId.isEmpty) return [];

  try {
    // Normalize the station ID format
    final stationPath = _normalizeStationId(params.stationId);

    print(
      'Fetching daily means for: $stationPath (original: ${params.stationId})',
    );

    // Calculate date range
    final endDate = DateTime.now();
    final startDate = endDate.subtract(Duration(days: params.days));

    // Get the years we need to query
    final years = <int>{};
    for (
      var date = startDate;
      date.isBefore(endDate) || date.isAtSameMomentAs(endDate);
      date = date.add(const Duration(days: 1))
    ) {
      years.add(date.year);
    }

    print('Querying years: $years');

    // Fetch data from readings/{year} documents
    final dailyMeans = <DailyMean>[];

    for (final year in years) {
      print('📅 Fetching readings for year: $year');
      print('   Path: stations/$stationPath/readings/$year');

      final doc = await FirebaseFirestore.instance
          .collection('stations')
          .doc(stationPath)
          .collection('readings')
          .doc(year.toString())
          .get();

      if (!doc.exists) {
        print('❌ No readings document found for year $year');
        continue;
      }

      print('✅ Found readings document for year $year');

      final data = doc.data();
      print('📦 Document data keys: ${data?.keys.toList()}');

      final dailyReadings = data?['daily_readings'] as Map<String, dynamic>?;

      if (dailyReadings == null) {
        print('❌ No daily_readings map found for year $year');
        print('   Available data: $data');
        continue;
      }

      print('✅ Found daily_readings map with ${dailyReadings.length} entries');
      print('   Sample dates: ${dailyReadings.keys.take(3).toList()}');

      // Extract provider and station_id from the parent document
      final parts = stationPath.split('.');
      String provider = 'environment_canada';
      String stationId = stationPath;

      if (parts.length == 2) {
        // Format: Provider.ENVIRONMENT_CANADA_08AB001
        final enumAndStation = parts[1].split('_');
        if (enumAndStation.length >= 2) {
          provider = enumAndStation
              .take(enumAndStation.length - 1)
              .join('_')
              .toLowerCase();
          stationId = enumAndStation.last;
        }
      }

      print('📍 Parsed provider: $provider, stationId: $stationId');

      // Convert each date entry to DailyMean
      var processedCount = 0;
      dailyReadings.forEach((dateStr, reading) {
        final readingMap = reading as Map<String, dynamic>;
        final date = DateTime.parse(dateStr);

        // Filter by date range
        if (date.isAfter(startDate.subtract(const Duration(days: 1))) &&
            date.isBefore(endDate.add(const Duration(days: 1)))) {
          final mean = DailyMean(
            provider: provider,
            stationId: stationId,
            date: dateStr,
            level: readingMap['mean_level'] as double?,
            discharge: readingMap['mean_discharge'] as double?,
            levelUnit: 'm',
            dischargeUnit: 'm³/s',
          );
          dailyMeans.add(mean);
          processedCount++;

          // Print first few entries for debugging
          if (processedCount <= 3) {
            print(
              '   📊 $dateStr: discharge=${mean.discharge}, level=${mean.level}',
            );
          }
        }
      });

      print('✅ Processed $processedCount readings from year $year');
    }

    // Sort by date
    dailyMeans.sort((a, b) => a.date.compareTo(b.date));

    print('🎯 FINAL RESULT: Found ${dailyMeans.length} daily mean records');
    if (dailyMeans.isNotEmpty) {
      print(
        '   Date range: ${dailyMeans.first.date} to ${dailyMeans.last.date}',
      );
      print(
        '   First entry: discharge=${dailyMeans.first.discharge}, level=${dailyMeans.first.level}',
      );
      print(
        '   Last entry: discharge=${dailyMeans.last.discharge}, level=${dailyMeans.last.level}',
      );
    }

    return dailyMeans;
  } catch (e) {
    print('Error fetching daily means for ${params.stationId}: $e');
    print('Stack trace: ${StackTrace.current}');
    return [];
  }
});

/// Stream provider for real-time station level updates
final stationLevelStreamProvider = StreamProvider.family<StationLevel?, String>(
  (ref, stationId) {
    if (stationId.isEmpty) {
      return Stream.value(null);
    }

    final docId = _normalizeStationId(stationId);

    return FirebaseFirestore.instance
        .collection('station_levels')
        .doc(docId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return StationLevel.fromFirestore(doc);
        });
  },
);

/// Normalize station ID to match Firestore document ID format
/// Handles formats like:
/// - "Provider.ENVIRONMENT_CANADA_08AB001" (actual format in Firestore)
/// - "environment_canada_08AB001" (expected format)
/// - "08AB001" (just the station code)
String _normalizeStationId(String stationId) {
  print('🔍 Normalizing stationId: $stationId');

  // If it already has the Provider. prefix, return as-is
  if (stationId.startsWith('Provider.')) {
    print('   ✅ Already has Provider. prefix');
    return stationId;
  }

  // If it's in lowercase underscore format, convert to Provider. format
  // "environment_canada_08AB001" -> "Provider.ENVIRONMENT_CANADA_08AB001"
  if (stationId.contains('_')) {
    final upperCase = stationId.toUpperCase();
    final normalized = 'Provider.$upperCase';
    print('   ✅ Converted from underscore format: $normalized');
    return normalized;
  }

  // If it's just a station code (e.g., "08HD006"), assume Environment Canada
  // "08HD006" -> "Provider.ENVIRONMENT_CANADA_08HD006"
  if (RegExp(r'^\d{2}[A-Z]{2}\d{3}$').hasMatch(stationId)) {
    final normalized = 'Provider.ENVIRONMENT_CANADA_$stationId';
    print('   ✅ Converted from station code: $normalized');
    return normalized;
  }

  // Return as-is if format is unknown
  print('   ⚠️  Unknown format, returning as-is');
  return stationId;
}

/// Parameters for daily means query
class DailyMeansParams {
  final String stationId;
  final int days;

  const DailyMeansParams({required this.stationId, this.days = 30});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailyMeansParams &&
          runtimeType == other.runtimeType &&
          stationId == other.stationId &&
          days == other.days;

  @override
  int get hashCode => stationId.hashCode ^ days.hashCode;
}
