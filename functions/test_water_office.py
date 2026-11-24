"""Tests for water_office. Run: python -m unittest test_water_office"""

import unittest
from datetime import date, datetime, timedelta, timezone

import water_office as wo

NOW = datetime(2026, 11, 24, 18, tzinfo=timezone.utc)  # Nov 24, Pacific
HEADER = ('ID,Date,Parameter/Paramètre,Value/Valeur,Qualifier/Qualificatif,'
          'Symbol/Symbole,Approval/Approbation,Grade/Classification,'
          'Qualifiers/Qualificatifs')


class FakeResponse:
    def __init__(self, text):
        self.text = text

    def raise_for_status(self):
        pass


def csv_between(start, end, flow=10.0, level=1.5):
    """5-minute rows like the Water Office returns, UTC times."""
    rows = [HEADER]
    t = start
    while t <= end:
        stamp = t.astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')
        rows.append(f'08GA072,{stamp},46,{level},,,Provisional/Provisoire,,')
        rows.append(f'08GA072,{stamp},47,{flow},,,Provisional/Provisoire,,')
        t += timedelta(minutes=5)
    return '\n'.join(rows)


def fake_get():
    calls = []

    def get(url, params, timeout):
        q = dict(params)
        calls.append(q)
        parse = lambda s: datetime.strptime(s, '%Y-%m-%d %H:%M:%S').replace(tzinfo=timezone.utc)
        return FakeResponse(csv_between(parse(q['start_date']), parse(q['end_date'])))
    get.calls = calls
    return get


class WaterOfficeTest(unittest.TestCase):
    def test_fills_complete_days_after_hydat_up_to_yesterday(self):
        get = fake_get()
        daily = wo.daily_means('08GA072', after=date(2026, 9, 30), now=NOW, get=get)
        days = sorted(daily)
        self.assertEqual(days[0], '2026-10-01')
        self.assertEqual(days[-1], '2026-11-23')
        self.assertEqual(len(days), 54)
        self.assertEqual(daily['2026-10-15'], {'mean_discharge': 10.0, 'mean_level': 1.5})
        # Two monthly requests, each for discharge and level.
        self.assertEqual(len(get.calls), 2)
        self.assertEqual(get.calls[0]['stations[]'], '08GA072')

    def test_chunks_meet_at_pacific_midnight_without_overlap(self):
        get = fake_get()
        wo.daily_means('08GA072', after=date(2026, 9, 30), now=NOW, get=get)
        first_end = datetime.strptime(get.calls[0]['end_date'], '%Y-%m-%d %H:%M:%S')
        second_start = datetime.strptime(get.calls[1]['start_date'], '%Y-%m-%d %H:%M:%S')
        self.assertEqual(second_start - first_end, timedelta(seconds=1))
        local = second_start.replace(tzinfo=timezone.utc).astimezone(wo.PACIFIC)
        self.assertEqual((local.hour, local.minute), (0, 0))

    def test_goes_back_about_eighteen_months_without_hydat(self):
        get = fake_get()
        wo.daily_means('08HD006', after=None, now=NOW, get=get)
        first = datetime.strptime(get.calls[0]['start_date'], '%Y-%m-%d %H:%M:%S')
        self.assertEqual(first.date(), date(2025, 5, 25))

    def test_nothing_to_do_when_hydat_is_current(self):
        get = fake_get()
        self.assertEqual(wo.daily_means('08GA072', after=date(2026, 11, 23), now=NOW, get=get), {})
        self.assertEqual(get.calls, [])

    def test_ignores_other_parameters_and_blank_values(self):
        sums = {}
        from collections import defaultdict
        sums = defaultdict(dict)
        wo.accumulate(HEADER + '\n08GA072,2026-10-01T19:00:00Z,5,12,,,,,\n'
                      '08GA072,2026-10-01T19:00:00Z,47,,,,,,\n'
                      '08GA072,2026-10-01T19:00:00Z,47,3.5,,,,,', sums)
        self.assertEqual(wo.means(sums), {'2026-10-01': {'mean_discharge': 3.5}})


if __name__ == '__main__':
    unittest.main()
