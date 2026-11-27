import '../models/realtime_flow.dart';

/// Picks the flow to record for a descent on [day] from hourly readings:
/// the reading closest to midday that day, or null if no reading falls on
/// that day.
double? flowNearMidday(List<FlowReading> readings, DateTime day) {
  final midday = DateTime(day.year, day.month, day.day, 12);
  double? best;
  Duration? bestGap;
  for (final r in readings) {
    final discharge = r.discharge;
    if (discharge == null) continue;
    final t = r.timestamp.toLocal();
    if (t.year != day.year || t.month != day.month || t.day != day.day) {
      continue;
    }
    final gap = t.difference(midday).abs();
    if (bestGap == null || gap < bestGap) {
      bestGap = gap;
      best = discharge;
    }
  }
  return best;
}

/// The daily mean discharge for [day] from a `station_data` year document's
/// `daily_readings` map (keyed `yyyy-MM-dd`), falling back to the closest
/// earlier day within [maxDaysBack]. Null when nothing is close enough.
double? dailyMeanOnOrBefore(
  Map<String, dynamic> dailyReadings,
  DateTime day, {
  int maxDaysBack = 7,
}) {
  for (var back = 0; back <= maxDaysBack; back++) {
    final key = dateKey(day.subtract(Duration(days: back)));
    final reading = dailyReadings[key];
    if (reading is Map) {
      final mean = reading['mean_discharge'];
      if (mean is num) return mean.toDouble();
    }
  }
  return null;
}

/// `yyyy-MM-dd`, the key format the Cloud Functions use.
String dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The flow to record for a descent on [day] on a dam-release gauge: the
/// day's highest scheduled flow, since the dam is off most of the day and
/// a paddler runs it while it's releasing. Null with no readings that day.
double? releaseFlowOn(List<FlowReading> readings, DateTime day) {
  double? best;
  for (final r in readings) {
    final discharge = r.discharge;
    if (discharge == null) continue;
    final t = r.timestamp.toLocal();
    if (t.year != day.year || t.month != day.month || t.day != day.day) {
      continue;
    }
    if (best == null || discharge > best) best = discharge;
  }
  return best;
}
