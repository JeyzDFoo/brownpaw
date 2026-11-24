import 'package:brownpaw/data/live_readings.dart';
import 'package:brownpaw/models/realtime_flow.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  final now = DateTime.utc(2026, 11, 24, 22);
  FlowReading at(int hoursAgo, double flow) => FlowReading(
    timestamp: now.subtract(Duration(hours: hoursAgo)),
    discharge: flow,
  );

  test('asks only for the hours the stored copy is missing', () {
    expect(hoursMissing([at(8, 1)], now), 9);
    expect(hoursMissing(const [], now), 720);
    expect(hoursBucket(9), 12);
    expect(hoursBucket(1), 3);
    expect(hoursBucket(5000), 720);
  });

  test('live readings replace stored ones from where they start', () {
    final stored = [at(10, 1), at(8, 2), at(6, 3)];
    final live = [at(7, 20), at(1, 30)];
    expect(mergeLive(stored, live, now).map((r) => r.discharge), [
      1,
      2,
      20,
      30,
    ]);
  });

  test('falls back to the stored copy when live fails', () {
    final stored = [at(24 * 40, 9), at(8, 2)];
    expect(mergeLive(stored, null, now).map((r) => r.discharge), [2]);
  });

  test('fetches CSV once and reuses it for five minutes', () async {
    var calls = 0;
    late Uri asked;
    final live = LiveReadings(
      endpoint: Uri.parse('https://example.test/api/live'),
      client: MockClient((request) async {
        calls++;
        asked = request.url;
        return http.Response(
          'datetime,discharge,level\n2026-11-24T21:00:00Z,79.1,\n',
          200,
        );
      }),
    );
    final first = await live.fetch('environment_canada_08HA011', 9, now: now);
    expect(first!.single.discharge, 79.1);
    expect(asked.queryParameters, {
      'station': 'environment_canada_08HA011',
      'hours': '12',
    });
    await live.fetch(
      'environment_canada_08HA011',
      9,
      now: now.add(const Duration(minutes: 4)),
    );
    expect(calls, 1);
    await live.fetch(
      'environment_canada_08HA011',
      9,
      now: now.add(const Duration(minutes: 6)),
    );
    expect(calls, 2);
  });

  test('a source error gives null, so the app uses the stored copy', () async {
    final live = LiveReadings(
      endpoint: Uri.parse('https://example.test/api/live'),
      client: MockClient((_) async => http.Response('source unavailable', 502)),
    );
    expect(await live.fetch('metro_vancouver_capilano', 3, now: now), isNull);
  });
}
