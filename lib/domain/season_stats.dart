import '../models/descent.dart';

/// Totals for the logbook header.
class SeasonStats {
  const SeasonStats({
    required this.year,
    required this.daysOnWater,
    required this.differentRuns,
    required this.newRuns,
  });

  final int year;

  /// Distinct calendar days with at least one descent this season.
  final int daysOnWater;

  /// Distinct runs paddled this season.
  final int differentRuns;

  /// Runs paddled this season that were never logged before it.
  final int newRuns;

  /// A season is a calendar year, the one [now] falls in.
  static SeasonStats from(List<Descent> descents, {DateTime? now}) {
    final year = (now ?? DateTime.now()).year;
    final days = <DateTime>{};
    final runsThisYear = <String>{};
    final runsBefore = <String>{};
    for (final d in descents) {
      if (d.date.year == year) {
        days.add(DateTime(d.date.year, d.date.month, d.date.day));
        runsThisYear.add(d.runId);
      } else if (d.date.year < year) {
        runsBefore.add(d.runId);
      }
    }
    return SeasonStats(
      year: year,
      daysOnWater: days.length,
      differentRuns: runsThisYear.length,
      newRuns: runsThisYear.difference(runsBefore).length,
    );
  }
}
