import 'package:brownpaw/domain/season_stats.dart';
import 'package:brownpaw/models/descent.dart';
import 'package:flutter_test/flutter_test.dart';

Descent d(String run, DateTime date) => Descent(
  id: '$run$date',
  runId: run,
  runName: run,
  userId: 'u',
  date: date,
  createdAt: date,
);

void main() {
  final now = DateTime(2026, 11, 24);

  test('counts distinct days, runs and runs new this season', () {
    final stats = SeasonStats.from([
      d('tamihi', DateTime(2026, 11, 9, 10)),
      d('canyon', DateTime(2026, 11, 9, 15)), // same day, second run
      d('tamihi', DateTime(2026, 10, 1)),
      d('mamquam', DateTime(2026, 6, 1)),
      d('tamihi', DateTime(2025, 5, 1)), // paddled last year
      d('seymour', DateTime(2024, 5, 1)), // not this year
    ], now: now);
    expect(stats.year, 2026);
    expect(stats.daysOnWater, 3);
    expect(stats.differentRuns, 3);
    expect(stats.newRuns, 2); // canyon and mamquam
  });

  test('empty logbook', () {
    final stats = SeasonStats.from(const [], now: now);
    expect(stats.daysOnWater, 0);
    expect(stats.differentRuns, 0);
    expect(stats.newRuns, 0);
  });
}
