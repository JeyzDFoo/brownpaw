"""Tests for transalta. Run: python -m unittest test_transalta"""

import unittest
from datetime import datetime, timedelta, timezone

import transalta

# Fri Nov 27 2026, 4:40 PM Alberta (UTC-6).
NOW = datetime(2026, 11, 27, 22, 40, tzinfo=timezone.utc)

DAYS = ['Fri, Nov 27', 'Sat, Nov 28', 'Sun, Nov 29', 'Mon, Nov 30', 'Tue, Dec 1']


def table(barrier=None, pocaterra=None, days=DAYS):
    """The island's table as TransAlta serves it (attributes trimmed):
    Barrier 28 from HE18 to HE23, Pocaterra 21 from HE18 to HE22."""
    barrier = barrier or (lambda he: 28 if 18 <= he <= 23 else 0)
    pocaterra = pocaterra or (lambda he: 21 if 18 <= he <= 22 else 0)
    head = ''.join(f'<th scope="colgroup" colspan="2"> {d} </th>' for d in days)
    sub = '<th scope="col"> Barrier </th><th scope="col"> Pocaterra </th>' * len(days)
    rows = ''.join(
        f'<tr><td> {he:02d} </td>'
        + f'<td> {barrier(he)} </td><td> {pocaterra(he)} </td>' * len(days)
        + '</tr>'
        for he in range(1, 25))
    return (
        '<div class="table-element"><table class="w-full"><thead>'
        f'<tr><th scope="col" rowspan="2"> Hour Ending Time </th>{head}</tr>'
        f'<tr>{sub}</tr></thead><tbody>{rows}</tbody></table></div>')


PAGE = (
    '<html><body><div>Loading river flow data...</div>'
    '<script type="module" data-astro-rerun>const headers = new Headers('
    '{"X-Netlify-Deploy-ID":"abc123"});let response = await fetch('
    '"/_server-islands/RiverFlowDataTableContents?e=XYZ%3D&amp;p=&amp;s=",'
    '{headers});</script></body></html>')


class FakeResponse:
    def __init__(self, text):
        self.text = text

    def raise_for_status(self):
        pass


def fake_get(island):
    calls = []

    def get(url, headers=None, timeout=None):
        calls.append((url, headers))
        return FakeResponse(PAGE if url == transalta.PAGE else island)

    get.calls = calls
    return get


def utc(y, m, d, h):
    return datetime(y, m, d, h, tzinfo=timezone.utc)


class FakeDoc:
    def __init__(self, store, path):
        self.store, self.path = store, path

    def get(self):
        data = self.store.get(self.path)
        return type('Snap', (), {
            'exists': data is not None,
            'to_dict': lambda s: data,
        })()

    def set(self, data, merge=False):
        if merge and self.path in self.store:
            self.store[self.path] = {**self.store[self.path], **data}
        else:
            self.store[self.path] = data


class FakeDb:
    def __init__(self):
        self.store = {}

    def collection(self, name):
        db = self

        class Col:
            def document(self, doc):
                return FakeDoc(db.store, f'{name}/{doc}')
        return Col()


class IslandRequestTest(unittest.TestCase):
    def test_finds_url_and_deploy_header(self):
        url, headers = transalta.island_request(PAGE)
        self.assertEqual(
            url, 'https://transalta.com/_server-islands/'
            'RiverFlowDataTableContents?e=XYZ%3D&p=&s=')
        self.assertEqual(headers['X-Netlify-Deploy-ID'], 'abc123')

    def test_missing_island_raises(self):
        with self.assertRaises(ValueError):
            transalta.island_request('<html>nothing here</html>')


class ParseTableTest(unittest.TestCase):
    def test_hour_ending_in_alberta_time(self):
        out = transalta.parse_table(table(), NOW)
        barrier = out['barrier']
        self.assertEqual(len(barrier), 24 * 5)
        # HE18 on Nov 27 is 5 PM to 6 PM Alberta = 23:00 UTC.
        self.assertEqual(barrier[utc(2026, 11, 27, 23)], 28)
        # HE17 (4 PM Alberta, 22:00 UTC) is off.
        self.assertEqual(barrier[utc(2026, 11, 27, 22)], 0)
        # HE23 is 10 PM to 11 PM Alberta = 04:00 UTC next day.
        self.assertEqual(barrier[utc(2026, 11, 28, 4)], 28)
        self.assertEqual(barrier[utc(2026, 11, 28, 5)], 0)
        # Pocaterra stops an hour earlier.
        self.assertEqual(out['pocaterra'][utc(2026, 11, 28, 3)], 21)
        self.assertEqual(out['pocaterra'][utc(2026, 11, 28, 4)], 0)

    def test_year_rolls_over(self):
        days = ['Thu, Dec 31', 'Fri, Jan 1']
        now = datetime(2026, 12, 31, 18, tzinfo=timezone.utc)
        out = transalta.parse_table(table(days=days), now)
        starts = sorted(out['barrier'])
        self.assertEqual(starts[0], utc(2026, 12, 31, 6))
        self.assertEqual(starts[-1], utc(2027, 1, 2, 5))

    def test_empty_table_raises(self):
        with self.assertRaises(ValueError):
            transalta.parse_table('<table></table>', NOW)


class UpdateTest(unittest.TestCase):
    def test_writes_history_schedule_and_summary(self):
        db = FakeDb()
        get = fake_get(table())
        now = utc(2026, 11, 28, 1) + timedelta(minutes=5)  # 7:05 PM Alberta
        flows = transalta.update_realtime(db, now, get)
        self.assertEqual(flows, {'transalta_barrier': 28, 'transalta_pocaterra': 21})
        self.assertEqual(get.calls[1][1]['X-Netlify-Deploy-ID'], 'abc123')

        current = db.store['station_current/transalta_barrier']
        self.assertEqual(current['kind'], 'dam_release')
        history = current['hourly_readings_csv'].splitlines()
        # Midnight to 7 PM Alberta: 20 started hours, ending on 28.
        self.assertEqual(len(history), 1 + 20)
        self.assertEqual(history[-1], '2026-11-28T01:00:00Z,28,')
        schedule = current['release_schedule_csv'].splitlines()
        self.assertEqual(schedule[0], 'start,flow')
        self.assertEqual(len(schedule), 1 + 24 * 5)
        self.assertEqual(schedule[1], '2026-11-27T06:00:00Z,0')

        summary = db.store['stations/transalta_barrier']
        self.assertEqual(summary['name'], 'Barrier Dam release')
        self.assertEqual(summary['flow'], 28)
        self.assertIn('45 minutes', summary['note'])

    def test_keeps_earlier_days(self):
        db = FakeDb()
        evening = utc(2026, 11, 28, 1, ) + timedelta(minutes=5)  # 7:05 PM
        transalta.update_realtime(db, evening, fake_get(table()))
        # Next day the page starts at Sat; Friday's hours are kept.
        later = evening + timedelta(days=1)
        transalta.update_realtime(db, later, fake_get(table(days=DAYS[1:] + ['Wed, Dec 2'])))
        history = transalta.parse_history(
            db.store['station_current/transalta_barrier']['hourly_readings_csv'])
        self.assertIn(utc(2026, 11, 27, 23), history)
        self.assertEqual(history[utc(2026, 11, 27, 23)], 28)
        self.assertNotIn(later + timedelta(hours=1), history)

    def test_failure_writes_nothing(self):
        db = FakeDb()

        def broken(url, headers=None, timeout=None):
            raise RuntimeError('down')

        self.assertEqual(transalta.update_realtime(db, NOW, broken), {})
        self.assertEqual(db.store, {})


class DailyTest(unittest.TestCase):
    def test_release_flow_per_alberta_day(self):
        points = {utc(2026, 11, 27, 6) + timedelta(hours=h):
                  (28.0 if 17 <= h % 24 <= 22 else 0.0) for h in range(48)}
        daily = transalta.daily_release(points)
        self.assertEqual(daily['2026-11-27'], {'mean_discharge': 28.0, 'release_hours': 6})
        self.assertEqual(daily['2026-11-28']['release_hours'], 6)

    def test_no_release_day_is_zero(self):
        daily = transalta.daily_release({utc(2026, 11, 27, 12): 0.0})
        self.assertEqual(daily['2026-11-27']['mean_discharge'], 0.0)


if __name__ == '__main__':
    unittest.main()
