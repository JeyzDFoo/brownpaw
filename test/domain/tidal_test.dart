import 'package:brownpaw/domain/tidal.dart';
import 'package:flutter_test/flutter_test.dart';

/// BC wall time (UTC-7) on Nov [day] 2026.
DateTime bc(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour + 7, minute);

/// Dairiki's Sechelt Rapids table for Nov 27-28 2026, as stored.
const doc = {
  'current_source': 'dairiki',
  'tide_station': 'Egmont',
  'current_events_csv': '''time,kind,knots
2026-11-27T07:48:00Z,ebb,14.3
2026-11-27T11:43:00Z,slack,0
2026-11-27T15:09:00Z,flood,17
2026-11-27T19:46:00Z,slack,0
2026-11-27T21:43:00Z,ebb,4.2
2026-11-27T23:43:00Z,slack,0
2026-11-28T01:33:00Z,flood,4.7
2026-11-28T03:21:00Z,slack,0
2026-11-28T08:46:00Z,ebb,13.7
2026-11-28T12:30:00Z,slack,0
2026-11-28T15:59:00Z,flood,16.6
2026-11-28T20:31:00Z,slack,0''',
  'tide_events_csv': '''time,kind,metres
2026-11-27T09:35:00Z,low,0.2
2026-11-27T17:28:00Z,high,5.1
2026-11-27T23:08:00Z,low,3.6''',
};

void main() {
  final p = TidalPredictions.fromDoc(doc);

  test('reads currents and tides', () {
    expect(p.currents, hasLength(12));
    expect(p.tides, hasLength(3));
    expect(p.sourceName, contains('dairiki'));
    expect(p.floods, hasLength(3));
    final big = p.floods.first;
    expect(big.knots, 17);
    expect(big.start, DateTime.utc(2026, 11, 27, 11, 43));
    expect(big.end, DateTime.utc(2026, 11, 27, 19, 46));
    expect(big.ebbBefore?.knots, 14.3);
  });

  test('the curve passes through its turning points', () {
    expect(p.speedAt(DateTime.utc(2026, 11, 27, 15, 9)), closeTo(17, 1e-9));
    expect(p.speedAt(DateTime.utc(2026, 11, 27, 11, 43)), closeTo(0, 1e-9));
    expect(p.speedAt(DateTime.utc(2026, 11, 27, 7, 48)), closeTo(-14.3, 1e-9));
    final between = p.speedAt(DateTime.utc(2026, 11, 27, 13, 26))!;
    expect(between, inExclusiveRange(5, 12));
    expect(p.tideAt(DateTime.utc(2026, 11, 27, 17, 28)), closeTo(5.1, 1e-9));
    expect(p.speedAt(DateTime.utc(2026, 12, 25)), isNull);
  });

  test('before the flood: the next max flood, with its slacks', () {
    final o = tidalOutlook(p, bc(27, 3));
    expect(o.headline, 'Next max flood');
    expect(o.knots, 17);
    expect(o.detail, 'Peaks 8:09 AM · slack 4:43 AM to 12:46 PM');
    expect(tidalCountdown(o, bc(27, 3)), 'Peaks in 5 h 9 min');
  });

  test('during the flood, then after its peak', () {
    final rising = tidalOutlook(p, bc(27, 6));
    expect(rising.headline, 'Flooding now');
    expect(rising.flooding, isTrue);
    final easing = tidalOutlook(p, bc(27, 10));
    expect(easing.headline, 'Flood easing');
    expect(tidalCountdown(easing, bc(27, 10)), 'Slack in 2 h 46 min');
  });

  test('after the big flood, the small night flood is next', () {
    final o = tidalOutlook(p, bc(27, 14));
    expect(o.knots, 4.7);
    expect(isDaylight(o.flood!.time, 49.74, -123.9), isFalse);
    expect(p.nextDaylightFlood(bc(27, 14), 49.74, -123.9)?.knots, 16.6);
  });

  test('with a place, a night flood gives way to the next daylight one', () {
    final o = tidalOutlook(p, bc(27, 14), lat: 49.74, lon: -123.9);
    expect(o.knots, 16.6);
    expect(o.headline, 'Next max flood');
    // Even while the night flood runs.
    final running = tidalOutlook(p, bc(27, 18), lat: 49.74, lon: -123.9);
    expect(running.knots, 16.6);
    expect(running.flooding, isFalse);
  });

  test("each day's best flood is in daylight", () {
    final day = tidalDayStart(bc(27, 12));
    expect(p.bestDaylightFlood(day, 49.74, -123.9)?.knots, 17);
    expect(p.floodsOn(day).map((f) => f.knots), [17, 4.7]);
  });

  test('sunrise and sunset at Egmont in late November', () {
    final (rise, set) = sunTimes(tidalDayStart(bc(27, 12)), 49.74, -123.9);
    expect(tidalWall(rise).hour, 8);
    expect(tidalWall(set).hour, 17);
  });

  test('ebb note compares the ebb before with the flood', () {
    expect(ebbNote(p.floods.first), 'Ebb before 14.3 kt: well matched');
    final weak = Flood(
      max: CurrentEvent(bc(28, 9), CurrentKind.flood, 12),
      ebbBefore: CurrentEvent(bc(28, 3), CurrentKind.ebb, 4),
    );
    expect(ebbNote(weak), contains('only 4.0 kt'));
  });

  test('short times for calendar cells', () {
    expect(tidalShortTime(bc(27, 8, 9)), '8a');
    expect(tidalShortTime(bc(27, 12, 46)), '1p');
    expect(tidalShortTime(bc(27, 9, 30)), '9:30a');
  });
}
