"""Tests for flowworks. Run: python -m unittest test_flowworks"""

import unittest
from datetime import datetime, timedelta, timezone

import flowworks

NOW = datetime(2026, 11, 24, 18, 5, tzinfo=timezone.utc)  # 10:05 Pacific


class FakeResponse:
    def __init__(self, body):
        self.body = body

    def raise_for_status(self):
        pass

    def json(self):
        return self.body


def fake_get(points, status=1):
    calls = []

    def get(url, timeout):
        calls.append(url)
        return FakeResponse({
            'requeststatus': status,
            'msg': 'Request OK.' if status == 1 else 'no',
            'datapoints': points,
        })
    get.calls = calls
    return get


def local(t):
    """Format a UTC instant as the Pacific wall clock the API sends."""
    return t.astimezone(flowworks.PST).strftime('%Y-%m-%dT%H:%M:%S')


class ParseTest(unittest.TestCase):
    def test_winter_times_are_pst(self):
        out = flowworks.parse_points([
            {'date': '2026-11-24T10:05:00', 'value': 7.313552},
        ])
        (t, v), = out.items()
        self.assertEqual(t, datetime(2026, 11, 24, 18, 5, tzinfo=timezone.utc))
        self.assertAlmostEqual(v, 7.313552)

    def test_summer_times_are_pdt(self):
        out = flowworks.parse_points([
            {'date': '2026-07-24T10:05:00', 'value': 3.0},
        ])
        t, = out
        self.assertEqual(t, datetime(2026, 7, 24, 17, 5, tzinfo=timezone.utc))

    def test_skips_bad_points(self):
        out = flowworks.parse_points([
            {'date': '2026-11-24T10:05:00', 'value': None},
            {'date': 'bad', 'value': 1},
            {'value': 2},
        ])
        self.assertEqual(out, {})

    def test_readings_are_oldest_first_and_rounded(self):
        t1, t2 = NOW - timedelta(minutes=5), NOW
        rows = flowworks.to_readings({t2: 7.313552, t1: 7.0})
        self.assertEqual(rows, [
            {'datetime': '2026-11-24T18:00:00Z', 'discharge': 7.0},
            {'datetime': '2026-11-24T18:05:00Z', 'discharge': 7.314},
        ])
        self.assertTrue(flowworks.to_csv(rows).endswith('2026-11-24T18:05:00Z,7.314,'))


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
    def points(self, hours):
        times = [NOW - timedelta(minutes=5 * i) for i in range(hours * 12, -1, -1)]
        return [{'date': local(t), 'value': 7.313552} for t in times]

    def test_realtime_writes_current_and_name(self):
        db = FakeDb()
        get = fake_get(self.points(6))
        flows = flowworks.update_realtime(db, NOW, get)
        self.assertEqual(flows, {'flowworks_lynn': 7.314})
        current = db.docs['station_current/flowworks_lynn']
        self.assertEqual(current['latest_reading']['discharge'], 7.314)
        self.assertEqual(current['provider'], 'flowworks')
        self.assertTrue(current['hourly_readings_csv'].startswith('datetime,discharge,level\n'))
        self.assertEqual(db.docs['stations/flowworks_lynn']['name'], flowworks.NAME)
        self.assertIn('/site/183/channel/674/', get.calls[0])
        self.assertTrue(get.calls[0].endswith('/intervalnum/30'))

    def test_failed_request_writes_nothing(self):
        db = FakeDb()
        flows = flowworks.update_realtime(db, NOW, fake_get([], status=0))
        self.assertEqual(flows, {})
        self.assertEqual(db.docs, {})

    def test_daily_writes_complete_days(self):
        written = {}

        class Store:
            def write_daily_doc(self, doc_id, daily):
                written[doc_id] = daily

        # Five Pacific days of hourly-ish points, ending at 10:05 on the 24th.
        start = datetime(2026, 11, 20, 18, 5, tzinfo=timezone.utc)
        points = []
        t = start
        while t <= NOW:
            points.append({'date': local(t), 'value': 4.0})
            t += timedelta(hours=1)
        out = flowworks.update_daily(Store(), NOW, fake_get(points))
        self.assertEqual(out['lynn'], 3)  # 21st, 22nd, 23rd; first day and today dropped
        self.assertEqual(written['flowworks_lynn']['2026-11-23'],
                         {'mean_discharge': 4.0})


if __name__ == '__main__':
    unittest.main()
