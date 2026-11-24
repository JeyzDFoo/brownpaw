import 'package:brownpaw/domain/run_suggestion.dart';
import 'package:brownpaw/models/descent.dart';
import 'package:brownpaw/models/river_run.dart';
import 'package:flutter_test/flutter_test.dart';

RiverRun run(String id, {double? lat, double? lng}) => RiverRun(
  riverId: id,
  name: id,
  river: id,
  province: 'BC',
  difficultyClass: 'III',
  verified: true,
  putInCoordinates: lat == null ? null : {'latitude': lat, 'longitude': lng!},
);

Descent descent(String runId, DateTime date, {List<String>? crew}) => Descent(
  id: '$runId-$date',
  runId: runId,
  runName: runId,
  userId: 'u',
  date: date,
  crew: crew,
  createdAt: date,
);

void main() {
  // Tamihi put-in on the Chilliwack, and a run far away in Squamish.
  final tamihi = run('tamihi', lat: 49.0675, lng: -121.8231);
  final mamquam = run('mamquam', lat: 49.7350, lng: -123.1000);
  final noCoords = run('seymour');
  final runs = [tamihi, mamquam, noCoords];

  test('nearest put-in wins when you are at one', () {
    final s = suggestRun(
      runs: runs,
      descents: [descent('seymour', DateTime(2026, 11, 1))],
      position: (latitude: 49.0680, longitude: -121.8240),
    );
    expect(s?.run.riverId, 'tamihi');
    expect(s?.reason, SuggestionReason.nearestPutIn);
  });

  test('a put-in more than 3 km away does not count', () {
    final s = suggestRun(
      runs: runs,
      descents: [descent('seymour', DateTime(2026, 11, 1))],
      position: (latitude: 49.2, longitude: -121.8),
    );
    expect(s?.reason, SuggestionReason.lastLogged);
  });

  test('otherwise the most recent descent', () {
    final s = suggestRun(
      runs: runs,
      descents: [
        descent('mamquam', DateTime(2026, 10, 1)),
        descent('seymour', DateTime(2026, 11, 1)),
      ],
    );
    expect(s?.run.riverId, 'seymour');
  });

  test('otherwise the most recently viewed run', () {
    final s = suggestRun(runs: runs, recentRunIds: ['gone', 'mamquam']);
    expect(s?.run.riverId, 'mamquam');
    expect(s?.reason, SuggestionReason.recentlyViewed);
  });

  test('nothing to go on gives no suggestion', () {
    expect(suggestRun(runs: runs), isNull);
    expect(suggestRun(runs: const []), isNull);
  });

  test('crew suggestions are ordered by how often you paddle together', () {
    final names = crewSuggestions([
      descent('a', DateTime(2026, 1, 1), crew: ['Sam', 'Priya']),
      descent('a', DateTime(2026, 1, 2), crew: ['Sam', ' Alex ']),
      descent('a', DateTime(2026, 1, 3), crew: ['Sam', 'Alex', '']),
    ]);
    expect(names, ['Sam', 'Alex', 'Priya']);
  });

  test('distanceKm is roughly right', () {
    // Vancouver to Squamish is about 45 km in a straight line.
    final km = distanceKm(49.2827, -123.1207, 49.7016, -123.1558);
    expect(km, inInclusiveRange(44, 48));
  });
}
