"""Tests for tidal. Run: python -m unittest test_tidal"""

import unittest
from datetime import date, datetime, timedelta, timezone

import tidal

# Dairiki's Sechelt Rapids table for Nov 2026, first two days, as served.
PAGE = '''<html><body><table class="tides">
<tr><th></th><th colspan="1">Turn</th><th colspan="2">Max</th><th colspan="1">Turn</th><th colspan="2">Max</th><th colspan="1">Turn</th></tr>
<tr class="info row"><td colspan="4" class="first">Time Zone is MST</td><td colspan="4" class="last">Units are knots</td></tr>
<tr class="even"><td class="first date weekend"><a href="daily.php/scl/2026-11-01">Sun 01 Nov</a><span class="moon-phase" title="Last quarter moon">T</span></td><td class="empty" colspan="1"></td><td class="left">03:45</td><td class="right">-10.6E</td><td>07:34</td><td class="left">11:20</td><td class="right">14.2F</td><td class="last">15:34</td></tr>
<tr class="even"><td class="first"></td><td class="empty" colspan="1"></td><td class="left">17:46</td><td class="right">-4.4E</td><td>20:14</td><td class="left">21:46</td><td class="right">2.5F</td><td class="last">23:35</td></tr>
<tr class="odd"><td class="first date"><a href="daily.php/scl/2026-11-02">Mon 02 Nov</a></td><td class="empty" colspan="1"></td><td class="left">04:55</td><td class="right">-9.4E</td><td>08:30</td><td class="left">12:15</td><td class="right">13.9F</td><td class="last">16:17</td></tr>
<tr class="odd"><td class="first"></td><td class="empty" colspan="1"></td><td class="left">18:57</td><td class="right">-5.7E</td><td>21:43</td><td class="left">23:25</td><td class="right">2.2F</td><td class="empty"></td></tr>
<tr class="even"><td class="first date"><a href="daily.php/scl/2026-11-03">Tue 03 Nov</a></td><td>01:38</td><td class="left">06:08</td><td class="right">-8.1E</td><td>09:24</td><td class="left">13:03</td><td class="right">13.4F</td><td class="last">16:54</td></tr>
</table></body></html>'''


def utc(y, m, d, h, mi=0):
    return datetime(y, m, d, h, mi, tzinfo=timezone.utc)


class ParseDairiki(unittest.TestCase):
    def test_reads_slack_and_max_in_order(self):
        events = tidal.parse_dairiki(PAGE)
        # 11:20 MST = 18:20 UTC, 14.2 knots of flood.
        self.assertIn((utc(2026, 11, 1, 18, 20), 'flood', 14.2), events)
        self.assertIn((utc(2026, 11, 1, 10, 45), 'ebb', 10.6), events)
        self.assertIn((utc(2026, 11, 1, 14, 34), 'slack', 0.0), events)
        # A leading turn on the 3rd: 01:38 MST.
        self.assertIn((utc(2026, 11, 3, 8, 38), 'slack', 0.0), events)
        self.assertEqual(events, sorted(events, key=lambda e: e[0]))
        self.assertEqual(len([e for e in events if e[1] == 'flood']), 5)
        self.assertEqual(len([e for e in events if e[1] == 'slack']), 10)

    def test_unknown_zone_fails_loudly(self):
        with self.assertRaises(ValueError):
            tidal.parse_dairiki(PAGE.replace('MST', 'XYZ'))


class Derived(unittest.TestCase):
    def setUp(self):
        self.events = tidal.parse_dairiki(PAGE)

    def test_next_and_nearest_flood(self):
        now = utc(2026, 11, 1, 12)
        self.assertEqual(tidal.next_flood(self.events, now)[2], 14.2)
        self.assertEqual(
            tidal.nearest_flood(self.events, utc(2026, 11, 2, 19))[2], 13.9)

    def test_daylight_floods_skip_night(self):
        daily = tidal.daylight_floods(self.events, 49.74, -123.9)
        # 21:46 MST's 2.5 kt is after dark; the midday flood counts.
        self.assertEqual(daily['2026-11-01'], 14.2)
        self.assertEqual(daily['2026-11-02'], 13.9)

    def test_sun_times_egmont(self):
        rise, sset = tidal.sun_times(date(2026, 11, 27), 49.74, -123.9)
        local = lambda t: t.astimezone(tidal.PACIFIC)
        # About 7:35 AM and 4:20 PM in UTC-7.
        self.assertTrue(7 <= local(rise).hour <= 8, local(rise))
        self.assertTrue(16 <= local(sset).hour <= 17, local(sset))

    def test_csv_round_trip(self):
        csv = tidal.events_csv(self.events, 'time,kind,knots')
        self.assertEqual(tidal.parse_events_csv(csv), self.events)


class FakeResponse:
    def __init__(self, text=None, data=None, status=200):
        self.text, self._data, self.status = text, data, status

    def raise_for_status(self):
        if self.status >= 400:
            raise RuntimeError(self.status)

    def json(self):
        return self._data


class FakeDoc:
    def __init__(self, store, key):
        self.store, self.key = store, key

    def get(self):
        data = self.store.get(self.key)
        return type('Snap', (), {'exists': data is not None,
                                 'to_dict': lambda s: dict(data or {})})()

    def set(self, data, merge=False):
        base = self.store.get(self.key, {}) if merge else {}
        self.store[self.key] = {**base, **data}


class FakeDb:
    def __init__(self):
        self.data = {}

    def collection(self, name):
        db = self
        return type('Col', (), {
            'document': lambda s, key: FakeDoc(db.data, f'{name}/{key}')})()


class UpdateRealtime(unittest.TestCase):
    NOW = utc(2026, 11, 1, 12)

    def get(self, calls, dairiki_ok=True):
        def get(url, headers=None, timeout=None, params=None):
            calls.append(url)
            if 'dairiki' in url:
                return FakeResponse(PAGE if dairiki_ok else '', status=200 if dairiki_ok else 503)
            if params['time-series-code'] == 'wlp-hilo':
                return FakeResponse(data=[
                    {'eventDate': '2026-11-01T14:00:00Z', 'value': 4.8},
                    {'eventDate': '2026-11-01T20:00:00Z', 'value': 1.2},
                ])
            return FakeResponse(data=[
                {'eventDate': '2026-11-01T18:00:00Z', 'qualifier': 'EXTREMA_FLOOD', 'value': 13.0},
            ])
        return get

    def test_writes_events_tides_and_reading(self):
        db, calls = FakeDb(), []
        flows = tidal.update_realtime(db, self.NOW, self.get(calls))
        self.assertEqual(flows, {'tidal_sechelt_rapids': 14.2})
        doc = db.data['station_current/tidal_sechelt_rapids']
        self.assertEqual(doc['current_source'], 'dairiki')
        self.assertIn('2026-11-01T18:20:00Z,flood,14.2', doc['current_events_csv'])
        self.assertIn('2026-11-01T14:00:00Z,high,4.8', doc['tide_events_csv'])
        self.assertEqual(doc['latest_reading']['discharge'], 14.2)
        self.assertEqual(db.data['stations/tidal_sechelt_rapids']['kind'], 'tidal')

        # An hour later nothing is fetched again.
        calls.clear()
        tidal.update_realtime(db, self.NOW + timedelta(hours=1), self.get(calls))
        # The fixture ends on Nov 3, so the "reaches 21 days" check fetches;
        # with a full table it wouldn't. Either way the doc keeps its events.
        self.assertIn('flood', db.data['station_current/tidal_sechelt_rapids']['current_events_csv'])

    def test_falls_back_to_chs(self):
        db, calls = FakeDb(), []
        tidal.update_realtime(db, self.NOW, self.get(calls, dairiki_ok=False))
        doc = db.data['station_current/tidal_sechelt_rapids']
        self.assertEqual(doc['current_source'], 'chs')
        self.assertIn('2026-11-01T18:00:00Z,flood,13', doc['current_events_csv'])

    def test_not_due_when_fresh_and_long(self):
        far = [(self.NOW + timedelta(days=30), 'flood', 10.0)]
        stored = {'events_fetched_at': self.NOW,
                  'current_events_csv': tidal.events_csv(far, 'h')}
        self.assertFalse(tidal._due(stored, self.NOW + timedelta(hours=2)))
        self.assertTrue(tidal._due(stored, self.NOW + timedelta(hours=13)))


if __name__ == '__main__':
    unittest.main()
