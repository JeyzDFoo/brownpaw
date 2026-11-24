"""
Daily history updater for Cloud Functions. Runs once a day.

Keeps `station_data/environment_canada_{code}/readings/{year}` complete, as
`daily_readings` maps keyed `yyyy-MM-dd`, from four sources:

1. Daily means from the realtime feed: every run re-averages all complete
   Pacific days in the 30 days of readings that `station_current` holds, so
   a missed run is filled in the next day.
2. HYDAT (the daily-mean API): approved data, published many months late.
   Fetched once per station, then refreshed monthly to pick up new releases
   and replace provisional days with approved ones. Each run spends at most
   HYDAT_BUDGET_SECONDS on it, oldest refresh first, so a short function
   timeout can't stop the daily step.
3. The Water Office's ~18-month archive of provisional readings, once per
   station, for the days between HYDAT's end and today (see
   water_office.py). Shares the HYDAT time budget.
4. History the old local script kept under
   `station_data/Provider.ENVIRONMENT_CANADA_{code}`, copied over once.

The parent document records the bookkeeping (`migrated_legacy`,
`hydat_fetched_at`, `water_office_filled_at`), so the job knows which
steps a station still needs. To do every station at once rather than a
few a day, run `python backfill.py` from this folder.
"""

import logging
import math
import os
import time
from collections import defaultdict
from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

import flowworks
import metro_vancouver
import water_office
from scripts.station_data_manager import StationDataManager
from scripts.models import Provider
from scripts.environment_canada.daily_data_service import DailyDataService


logger = logging.getLogger(__name__)

PROVIDER = Provider.ENVIRONMENT_CANADA.value
PACIFIC = ZoneInfo('America/Vancouver')
HYDAT_YEARS_DAYS = 1825
HYDAT_REFRESH = timedelta(days=30)
# The daily function has a 300 s timeout; leave room for the other gauges.
HYDAT_BUDGET_SECONDS = float(os.environ.get('HYDAT_BUDGET_SECONDS', '180'))


def history_doc_id(code: str) -> str:
    """`station_data` document id, the same form `station_current` uses."""
    return f"{PROVIDER}_{code}"


def legacy_doc_id(code: str) -> str:
    """Where the old local script kept history (an enum's str())."""
    return f"Provider.ENVIRONMENT_CANADA_{code}"


def parse_hourly_csv(csv: str) -> list:
    """`datetime,discharge,level` rows from `station_current`."""
    readings = []
    for line in (csv or '').split('\n')[1:]:
        parts = line.strip().split(',')
        if len(parts) < 3 or not parts[0]:
            continue
        reading = {'datetime': parts[0]}
        try:
            for key, text in (('discharge', parts[1]), ('level', parts[2])):
                value = float(text) if text else None
                if value is not None and math.isfinite(value):
                    reading[key] = value
        except ValueError:
            continue
        readings.append(reading)
    return readings


def daily_means(readings: list, now: datetime) -> dict:
    """Mean discharge and level for each complete Pacific day in [readings].

    Today is left out (still filling), and so is the earliest day, which
    the 30-day window cuts part way through.
    """
    today = now.astimezone(PACIFIC).date()
    by_day = defaultdict(list)
    for r in readings:
        try:
            dt = datetime.fromisoformat(r['datetime'].replace('Z', '+00:00'))
        except (KeyError, ValueError):
            continue
        if dt.tzinfo is None:
            dt = dt.replace(tzinfo=timezone.utc)
        by_day[dt.astimezone(PACIFIC).date()].append(r)

    if not by_day:
        return {}
    first = min(by_day)
    out = {}
    for day, rows in by_day.items():
        if day >= today or day == first:
            continue
        mean = {}
        discharges = [r['discharge'] for r in rows if r.get('discharge') is not None]
        levels = [r['level'] for r in rows if r.get('level') is not None]
        if discharges:
            mean['mean_discharge'] = round(sum(discharges) / len(discharges), 2)
        if levels:
            mean['mean_level'] = round(sum(levels) / len(levels), 3)
        if mean:
            out[day.isoformat()] = mean
    return out


def by_year(daily: dict) -> dict:
    years = defaultdict(dict)
    for date_str, value in daily.items():
        years[int(date_str[:4])][date_str] = value
    return dict(years)


def needs_hydat(meta: dict, now: datetime) -> bool:
    fetched = meta.get('hydat_fetched_at')
    if fetched is None:
        return True
    if fetched.tzinfo is None:
        fetched = fetched.replace(tzinfo=timezone.utc)
    return now - fetched >= HYDAT_REFRESH


def hydat_order(metas: dict) -> list:
    """Stations due a HYDAT fetch first: never fetched, then oldest."""
    floor = datetime.min.replace(tzinfo=timezone.utc)

    def key(code):
        fetched = metas[code].get('hydat_fetched_at')
        if fetched is None:
            return floor
        return fetched if fetched.tzinfo else fetched.replace(tzinfo=timezone.utc)

    return sorted(metas, key=key)


class HistoryStore:
    """Firestore reads and writes for `station_data`."""

    def __init__(self, db):
        self.db = db

    def _station(self, doc_id):
        return self.db.collection('station_data').document(doc_id)

    def meta(self, code: str) -> dict:
        doc = self._station(history_doc_id(code)).get()
        return (doc.to_dict() or {}) if doc.exists else {}

    def set_meta(self, code: str, fields: dict):
        self._station(history_doc_id(code)).set(
            {'provider': PROVIDER, 'station_id': code, **fields}, merge=True)

    def write_daily(self, code: str, daily: dict):
        """Merges [daily] into the year documents; other days are kept."""
        self.write_daily_doc(history_doc_id(code), daily)

    def write_daily_doc(self, doc_id: str, daily: dict):
        if not daily:
            return
        batch = self.db.batch()
        station = self._station(doc_id)
        for year, readings in by_year(daily).items():
            batch.set(station.collection('readings').document(str(year)), {
                'year': year,
                'daily_readings': readings,
                'updated_at': datetime.now(timezone.utc),
            }, merge=True)
        batch.commit()

    def legacy_daily(self, code: str) -> dict:
        daily = {}
        for doc in self._station(legacy_doc_id(code)).collection('readings').stream():
            readings = (doc.to_dict() or {}).get('daily_readings')
            if isinstance(readings, dict):
                daily.update(readings)
        return daily

    def hourly_csv(self, code: str) -> str:
        doc = self.db.collection('station_current').document(history_doc_id(code)).get()
        return (doc.to_dict() or {}).get('hourly_readings_csv', '') if doc.exists else ''


def update_station(code: str, meta: dict, store: HistoryStore, now: datetime) -> dict:
    """Copies legacy history once, then logs the realtime daily means."""
    result = {'station_id': code, 'status': 'success'}
    if not meta.get('migrated_legacy'):
        legacy = store.legacy_daily(code)
        # Legacy first, so anything newer written below wins.
        store.write_daily(code, legacy)
        store.set_meta(code, {'migrated_legacy': True})
        result['legacy_days'] = len(legacy)

    means = daily_means(parse_hourly_csv(store.hourly_csv(code)), now)
    store.write_daily(code, means)
    result['realtime_days'] = len(means)
    if not means:
        result['status'] = 'no_realtime'
    return result


def fetch_hydat(code: str, store: HistoryStore, service: DailyDataService, now: datetime) -> int:
    """Writes up to 5 years of approved daily means; returns days written."""
    daily = service.fetch_historical_data(code, days=HYDAT_YEARS_DAYS)
    store.write_daily(code, daily)
    fields = {'hydat_fetched_at': now}
    if daily:
        fields['hydat_last_date'] = max(daily)
    store.set_meta(code, fields)
    return len(daily)


def fill_from_water_office(code: str, meta: dict, store: HistoryStore,
                           now: datetime, get=None) -> int:
    """Fills the days between HYDAT's end and today from the Water Office's
    ~18-month archive, once per station. HYDAT days are left alone; the
    monthly HYDAT refresh replaces these provisional days as they're
    approved."""
    last = meta.get('hydat_last_date')
    after = date.fromisoformat(last) if last else None
    kwargs = {'get': get} if get else {}
    daily = water_office.daily_means(code, after=after, now=now, **kwargs)
    store.write_daily(code, daily)
    store.set_meta(code, {'water_office_filled_at': now,
                          'water_office_days': len(daily)})
    return len(daily)


def run_update(now: datetime = None, store: HistoryStore = None,
               service: DailyDataService = None, stations=None) -> dict:
    """Main function for the daily history update."""
    start = time.monotonic()
    now = now or datetime.now(timezone.utc)
    if store is None or stations is None:
        manager = StationDataManager()
        store = store or HistoryStore(manager.db)
        if stations is None:
            stations = manager.get_all_river_run_stations().get(
                Provider.ENVIRONMENT_CANADA, set())
    service = service or DailyDataService()
    logger.info(f"Daily history update for {len(stations)} stations")

    metas = {}
    results = []
    for code in sorted(stations):
        try:
            metas[code] = store.meta(code)
            results.append(update_station(code, metas[code], store, now))
        except Exception as e:
            logger.error(f"  {code}: daily update failed: {e}", exc_info=True)
            results.append({'station_id': code, 'status': 'error', 'error': str(e)})

    hydat_done, hydat_pending, filled = 0, 0, 0
    for code in hydat_order(metas):
        meta = metas[code]
        due_hydat = needs_hydat(meta, now)
        due_fill = not meta.get('water_office_filled_at')
        if not (due_hydat or due_fill):
            continue
        if time.monotonic() - start > HYDAT_BUDGET_SECONDS:
            hydat_pending += 1
            continue
        if due_hydat:
            try:
                days = fetch_hydat(code, store, service, now)
                logger.info(f"  {code}: {days} HYDAT days")
                hydat_done += 1
                meta.update(store.meta(code))
            except Exception as e:
                logger.error(f"  {code}: HYDAT fetch failed: {e}")
                continue
        if due_fill:
            try:
                days = fill_from_water_office(code, meta, store, now)
                logger.info(f"  {code}: {days} Water Office days")
                filled += 1
            except Exception as e:
                logger.error(f"  {code}: Water Office fill failed: {e}")

    try:
        metro = metro_vancouver.update_daily(store, now)
    except Exception as e:
        logger.error(f"Metro Vancouver daily failed: {e}", exc_info=True)
        metro = {'error': str(e)}

    try:
        lynn = flowworks.update_daily(store, now)
    except Exception as e:
        logger.error(f"Flowworks daily failed: {e}", exc_info=True)
        lynn = {'error': str(e)}

    summary = {
        'stations': len(stations),
        'metro_vancouver': metro,
        'flowworks': lynn,
        'success': sum(1 for r in results if r['status'] == 'success'),
        'failed': sum(1 for r in results if r['status'] == 'error'),
        'hydat_fetched': hydat_done,
        'hydat_pending': hydat_pending,
        'water_office_filled': filled,
        'duration_seconds': round(time.monotonic() - start, 2),
    }
    logger.info(f"Daily history update done: {summary}")
    return summary
