import 'package:brownpaw/domain/dam_release.dart';
import 'package:brownpaw/domain/flow_lookup.dart';
import 'package:brownpaw/models/realtime_flow.dart';
import 'package:flutter_test/flutter_test.dart';

/// Barrier as published on Nov 27 2026: 28 m³/s from 5 PM to 11 PM
/// Alberta time (23:00 to 05:00 UTC), three days.
String csv({int days = 3}) {
  final lines = ['start,flow'];
  final start = DateTime.utc(2026, 11, 27, 6); // midnight Alberta
  for (var h = 0; h < 24 * days; h++) {
    final t = start.add(Duration(hours: h));
    final flow = (h % 24) >= 17 && (h % 24) <= 22 ? 28 : 0;
    lines.add('${t.toIso8601String().replaceFirst('.000', '')},$flow');
  }
  return lines.join('\n');
}

DateTime alberta(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour + 6, minute);

void main() {
  final schedule = ReleaseSchedule.fromCsv(csv());

  test('merges hours into windows', () {
    final w = schedule.windows;
    expect(w, hasLength(3));
    expect(w.first.start, alberta(27, 17));
    expect(w.first.end, alberta(27, 23));
    expect(w.first.flowText, '28');
    expect(w.first.timeText, '5 PM–11 PM');
  });

  test('releasing now', () {
    final o = releaseOutlook(schedule, alberta(27, 19, 30));
    expect(o.releasing, isTrue);
    expect(o.headline, 'Releasing until 11 PM');
    expect(o.detail, '28 m³/s since 5 PM');
    expect(o.flow, 28);
  });

  test('next release today, then tomorrow', () {
    final before = releaseOutlook(schedule, alberta(27, 16, 40));
    expect(before.releasing, isFalse);
    expect(before.headline, 'Next release today');
    expect(before.detail, '28 m³/s · 5 PM–11 PM');

    final after = releaseOutlook(schedule, alberta(27, 23, 15));
    expect(after.headline, 'Next release tomorrow');
  });

  test('a later day by name, and nothing left', () {
    final o = releaseOutlook(
      ReleaseSchedule([
        (start: alberta(27, 10), flow: 0),
        (start: alberta(29, 9), flow: 20),
      ]),
      alberta(27, 10, 30),
    );
    expect(o.headline, 'Next release Sun, Nov 29');

    final none = releaseOutlook(
      ReleaseSchedule([(start: alberta(27, 10), flow: 0)]),
      alberta(27, 10, 30),
    );
    expect(none.headline, 'No release scheduled');
    expect(none.flow, isNull);
  });

  test('no schedule', () {
    expect(releaseOutlook(null, alberta(27, 12)).headline, 'No schedule yet');
  });

  test('days are Alberta days from today', () {
    final days = schedule.days(alberta(28, 1));
    expect(days, hasLength(2));
    expect(days.first.start, alberta(28, 0));
    expect(days.first.hours, hasLength(24));
    expect(days.first.windows.single.timeText, '5 PM–11 PM');
  });

  test('labels', () {
    expect(hourLabel(alberta(27, 0)), 'Midnight');
    expect(hourLabel(alberta(27, 12)), 'Noon');
    expect(hourLabel(alberta(27, 17)), '5 PM');
    expect(dayLabel(alberta(30, 2), alberta(27, 23)), 'Mon, Nov 30');
  });

  test('varying flow shows a range', () {
    final w = releaseWindows([
      (start: alberta(27, 8), flow: 21),
      (start: alberta(27, 9), flow: 28),
    ]);
    expect(w.single.flowText, '21–28');
    expect(w.single.flow, 28);
  });

  test('isReleaseGauge', () {
    expect(isReleaseGauge('transalta_barrier'), isTrue);
    expect(isReleaseGauge('environment_canada_08GA072'), isFalse);
  });

  test('a logged descent records the day\'s release', () {
    final readings = [
      for (var h = 0; h < 24; h++)
        FlowReading(
          timestamp: alberta(27, h),
          discharge: h >= 17 && h <= 22 ? 28 : 0,
        ),
    ];
    expect(releaseFlowOn(readings, alberta(27, 12).toLocal()), 28);
  });
}
