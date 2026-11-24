"""Tests for metro_vancouver. Run: python -m unittest test_metro_vancouver"""

import unittest
from datetime import datetime, timedelta, timezone

import metro_vancouver as mv

NOW = datetime(2026, 11, 24, 18, tzinfo=timezone.utc)


class FakeResponse:
    def __init__(self, values):
        self.values = values

    def raise_for_status(self):
        pass

    def json(self):
        return {'pointId': 1, 'tagName': 'x', 'values': self.values}


def fake_get(series):
    calls = []

    def get(url, params, timeout):
        calls.append(params)
        return FakeResponse(series[params['tagName'].split('.')[-1]])
    get.calls = calls
    return get


def local(t):
    """Metro Vancouver's API times: Pacific, no offset."""
    return t.astimezone(mv.PACIFIC).strftime('%Y-%m-%dT%H:%M:%S')


class ParseTest(unittest.TestCase):
    def test_times_are_pacific_local(self):
        out = mv.parse_values([{'value': 4.0, 'time': '2026-11-24T10:00:00'}])
        (t, v), = out.items()
        self.assertEqual(t, datetime(2026, 11, 24, 10, tzinfo=mv.PACIFIC))
        self.assertEqual(v, 4.0)

    def test_skips_missing_values(self):
        out = mv.parse_values([{'value': None, 'time': '2026-11-24T10:00:00'},
                               {'value': 1, 'time': 'bad'}, {'value': 2}])
        self.assertEqual(out, {})

    def test_combines_flow_and_level_oldest_first(self):
        t1, t2 = NOW - timedelta(minutes=15), NOW
        rows = mv.combine({t2: 10.5, t1: 10.0}, {t1: 1.2})
        self.assertEqual(rows, [
            {'datetime': '2026-11-24T17:45:00Z', 'discharge': 10.0, 'level': 1.2},
            {'datetime': '2026-11-24T18:00:00Z', 'discharge': 10.5},
        ])
        self.assertEqual(mv.to_csv(rows).split('\n')[2], '2026-11-24T18:00:00Z,10.5,')


class TrendTest(unittest.TestCase):
    def rows(self, then, now):
        return [{'datetime': '2026-11-24T14:00:00Z', 'discharge': then},
                {'datetime': '2026-11-24T18:00:00Z', 'discharge': now}]

    def test_trend(self):
        self.assertEqual(mv.trend(self.rows(10, 12)), 'rising')
        self.assertEqual(mv.trend(self.rows(10, 8)), 'falling')
        self.assertEqual(mv.trend(self.rows(10, 10.2)), 'stable')


class FakeDoc:
    def __init__(self, store, path):
        self.store, self.path = store, path

    def set(self, data, merge=False):
        self.store[self.path] = data


class FakeDb:
    def __init__(self):
        self.docs = {}

    def collection(self, name):
        db = self

        class C:
            def document(self, doc_id):
                return FakeDoc(db.docs, f"{name}/{doc_id}")
        return C()


class UpdateTest(unittest.TestCase):
    def series(self, hours):
        times = [NOW - timedelta(hours=h) for h in range(hours, -1, -1)]
        return {
            'FLOW': [{'value': 20.0, 'time': local(t)} for t in times],
            'LEVEL': [{'value': 1.5, 'time': local(t)} for t in times],
        }

    def test_realtime_writes_current_and_names(self):
        db = FakeDb()
        get = fake_get(self.series(48))
        flows = mv.update_realtime(db, NOW, get)
        self.assertEqual(flows, {'metro_vancouver_capilano': 20.0,
                                 'metro_vancouver_seymour': 20.0})
        current = db.docs['station_current/metro_vancouver_seymour']
        self.assertEqual(current['latest_reading']['discharge'], 20.0)
        self.assertTrue(current['hourly_readings_csv'].startswith('datetime,discharge,level\n'))
        self.assertEqual(db.docs['stations/metro_vancouver_capilano']['provider'], 'metro_vancouver')
        self.assertEqual(get.calls[0]['tagName'], 'UNIDATA.Capilano.FLOW')
        self.assertTrue(get.calls[0]['end'].endswith('GMT'))

    def test_daily_writes_complete_days(self):
        written = {}

        class Store:
            def write_daily_doc(self, doc_id, daily):
                written[doc_id] = daily

        out = mv.update_daily(Store(), NOW, fake_get(self.series(24 * 5)))
        self.assertEqual(out['capilano'], 4)  # 5 days back, minus today and the partial first
        self.assertEqual(written['metro_vancouver_capilano']['2026-11-23'],
                         {'mean_discharge': 20.0, 'mean_level': 1.5})


if __name__ == '__main__':
    unittest.main()
