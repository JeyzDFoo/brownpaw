"""Tests for daily_updater. Run: python -m unittest test_daily_updater"""

import sys
import types
import unittest
from datetime import datetime, timedelta, timezone

# The Firestore manager isn't needed here; stub it so tests run without
# firebase_admin credentials.
_manager = types.ModuleType('scripts.station_data_manager')
_manager.StationDataManager = object
sys.modules.setdefault('scripts.station_data_manager', _manager)

import daily_updater  # noqa: E402
import metro_vancouver  # noqa: E402
from unittest import mock  # noqa: E402
from daily_updater import (  # noqa: E402
    daily_means, needs_hydat, parse_hourly_csv, run_update, update_station)

NOW = datetime(2026, 11, 24, 18, tzinfo=timezone.utc)  # 10:00 Pacific


def csv_for(hours, start, flow=lambda i: 10.0):
    rows = ['datetime,discharge,level']
    for i in range(hours):
        t = start + timedelta(hours=i)
        rows.append(f"{t.strftime('%Y-%m-%dT%H:%M:%SZ')},{flow(i)},1.5")
    return '\n'.join(rows)


class FakeStore:
    def __init__(self, csv='', legacy=None, meta=None):
        self.csv = csv
        self.legacy = legacy or {}
        self.metas = meta or {}
        self.daily = {}
        self.writes = []

    def meta(self, code):
        return dict(self.metas.get(code, {}))

    def set_meta(self, code, fields):
        self.metas.setdefault(code, {}).update(fields)

    def write_daily(self, code, daily):
        self.writes.append(dict(daily))
        self.daily.setdefault(code, {}).update(daily)

    def legacy_daily(self, code):
        return dict(self.legacy)

    def hourly_csv(self, code):
        return self.csv


class FakeService:
    def __init__(self, daily):
        self.daily = daily
        self.calls = []

    def fetch_historical_data(self, code, days):
        self.calls.append(code)
        return dict(self.daily)


class DailyMeansTest(unittest.TestCase):
    def test_averages_complete_pacific_days_only(self):
        # 30 days of hourly readings ending now.
        start = NOW - timedelta(hours=720)
        means = daily_means(parse_hourly_csv(csv_for(721, start)), NOW)
        days = sorted(means)
        # Today (Nov 24 Pacific) and the cut-off first day are left out.
        self.assertEqual(days[-1], '2026-11-23')
        self.assertEqual(days[0], '2026-10-26')
        self.assertEqual(len(days), 29)
        self.assertEqual(means['2026-11-23'], {'mean_discharge': 10.0, 'mean_level': 1.5})

    def test_days_split_on_pacific_midnight(self):
        # Local midnight, whatever BC's offset is that day.
        start = datetime(2026, 11, 21, tzinfo=daily_updater.PACIFIC).astimezone(timezone.utc)
        flow = lambda i: 5.0 if i < 24 else (20.0 if i < 48 else 1.0)
        means = daily_means(parse_hourly_csv(csv_for(72, start, flow)), NOW)
        self.assertEqual(means['2026-11-22']['mean_discharge'], 20.0)

    def test_skips_blank_and_bad_rows(self):
        csv = 'datetime,discharge,level\n2026-11-20T12:00:00Z,,1.2\nbad,x,y\n\n'
        self.assertEqual(parse_hourly_csv(csv), [{'datetime': '2026-11-20T12:00:00Z', 'level': 1.2}])


class UpdateStationTest(unittest.TestCase):
    def test_copies_legacy_once_then_logs_realtime(self):
        store = FakeStore(
            csv=csv_for(721, NOW - timedelta(hours=720)),
            legacy={'2025-06-01': {'mean_discharge': 50.0}})
        result = update_station('08GA072', store.meta('08GA072'), store, NOW)
        self.assertEqual(result['legacy_days'], 1)
        self.assertEqual(result['realtime_days'], 29)
        self.assertIn('2025-06-01', store.daily['08GA072'])
        self.assertTrue(store.metas['08GA072']['migrated_legacy'])

        store.writes.clear()
        result = update_station('08GA072', store.meta('08GA072'), store, NOW)
        self.assertNotIn('legacy_days', result)
        self.assertEqual(len(store.writes), 1)


@mock.patch.object(metro_vancouver, 'update_daily', lambda store, now: {})
class HydatTest(unittest.TestCase):
    def test_needs_hydat_when_never_fetched_or_a_month_old(self):
        self.assertTrue(needs_hydat({}, NOW))
        self.assertFalse(needs_hydat({'hydat_fetched_at': NOW - timedelta(days=3)}, NOW))
        self.assertTrue(needs_hydat({'hydat_fetched_at': NOW - timedelta(days=31)}, NOW))

    def test_run_fetches_due_stations_and_hydat_overrides_provisional(self):
        store = FakeStore(
            legacy={'2025-01-02': {'mean_discharge': 1.0}},
            meta={'08AAA01': {'migrated_legacy': True, 'hydat_fetched_at': NOW}})
        service = FakeService({'2025-01-02': {'mean_discharge': 2.0}})
        summary = run_update(now=NOW, store=store, service=service,
                             stations={'08AAA01', '08BBB02'})
        self.assertEqual(service.calls, ['08BBB02'])
        self.assertEqual(summary['hydat_fetched'], 1)
        self.assertEqual(store.daily['08BBB02']['2025-01-02']['mean_discharge'], 2.0)
        self.assertEqual(store.metas['08BBB02']['hydat_last_date'], '2025-01-02')

    def test_time_budget_leaves_the_rest_for_tomorrow(self):
        old = daily_updater.HYDAT_BUDGET_SECONDS
        daily_updater.HYDAT_BUDGET_SECONDS = -1
        try:
            service = FakeService({})
            summary = run_update(now=NOW, store=FakeStore(), service=service,
                                 stations={'08AAA01'})
        finally:
            daily_updater.HYDAT_BUDGET_SECONDS = old
        self.assertEqual(service.calls, [])
        self.assertEqual(summary['hydat_pending'], 1)


if __name__ == '__main__':
    unittest.main()
