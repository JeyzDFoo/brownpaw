/// Model for real-time flow data parsed from CSV
class RealtimeFlow {
  final List<FlowReading> readings;

  const RealtimeFlow({required this.readings});

  /// Parse CSV data from station_current collection
  /// Format: datetime,discharge,level
  /// Example:
  /// datetime,discharge,level
  /// 2026-01-05T22:05:00Z,None,7.978
  /// 2026-01-05T22:00:00Z,None,7.976
  factory RealtimeFlow.fromCSV(String csvData) {
    final readings = <FlowReading>[];

    if (csvData.isEmpty) {
      return RealtimeFlow(readings: readings);
    }

    // Split by lines
    final lines = csvData.trim().split('\n');

    // Skip if no data (just header or empty)
    if (lines.length < 2) {
      return RealtimeFlow(readings: readings);
    }

    // Skip header line, parse data lines
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      final parts = line.split(',');
      if (parts.length < 3) continue;

      try {
        final timestamp = DateTime.parse(parts[0]);
        final discharge = parts[1] == 'None' ? null : double.tryParse(parts[1]);
        final level = parts[2] == 'None' ? null : double.tryParse(parts[2]);

        readings.add(
          FlowReading(timestamp: timestamp, discharge: discharge, level: level),
        );
      } catch (e) {
        // Skip invalid lines
        continue;
      }
    }

    // Sort by timestamp (newest first in CSV, so reverse for chronological order)
    readings.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return RealtimeFlow(readings: readings);
  }

  /// Get the most recent reading
  FlowReading? get latestReading => readings.isEmpty ? null : readings.last;

  /// Get the oldest reading
  FlowReading? get oldestReading => readings.isEmpty ? null : readings.first;

  /// Calculate trend based on recent readings
  String? get trend {
    if (readings.length < 2) return null;

    final latest = readings.last;
    final previous = readings[readings.length - 2];

    // Use level if available, otherwise discharge
    final latestValue = latest.level ?? latest.discharge;
    final previousValue = previous.level ?? previous.discharge;

    if (latestValue == null || previousValue == null) return null;

    final diff = latestValue - previousValue;
    if (diff.abs() < 0.01) {
      return 'stable';
    } else if (diff > 0) {
      return 'rising';
    } else {
      return 'falling';
    }
  }

  @override
  String toString() {
    return 'RealtimeFlow(readings: ${readings.length}, '
        'latest: ${latestReading?.timestamp}, trend: $trend)';
  }
}

/// Model for a single reading
class FlowReading {
  final DateTime timestamp;
  final double? discharge;
  final double? level;

  const FlowReading({required this.timestamp, this.discharge, this.level});

  @override
  String toString() {
    return 'HourlyReading(timestamp: $timestamp, '
        'discharge: $discharge, level: $level)';
  }
}
