"""
Metro Vancouver river gauges: the Capilano and Seymour below their dams.

Metro Vancouver publishes 15-minute level (m) and flow (m3/s) readings at
https://metrovancouver.org/services/water/seymour-and-capilano-river-levels
from a PI historian behind service.metrovancouver.org/riverlevels. The API
returns up to a year of readings, with times in Pacific local time and no
offset. Used with permission arranged through the Vancouver club.

Stations are stored like Environment Canada's, under
`station_current/metro_vancouver_{key}` and
`station_data/metro_vancouver_{key}/readings/{year}`, so the app and the
flow alerts read them the same way. Runs point at them with
`stationId: metro_vancouver_capilano`.
"""

import logging
import math
from datetime import datetime, timedelta, timezone
from email.utils import format_datetime
from zoneinfo import ZoneInfo

import requests

logger = logging.getLogger(__name__)

PROVIDER = 'metro_vancouver'
PACIFIC = ZoneInfo('America/Vancouver')
API = 'https://service.metrovancouver.org/riverlevels/api/PIData'
TIMEOUT = 30

STATIONS = {
    'capilano': {'tag': 'Capilano', 'name': 'Capilano River below Cleveland Dam'},
    'seymour': {'tag': 'Seymour', 'name': 'Seymour River below Seymour Falls Dam'},
}


def doc_id(key: str) -> str:
    return f"{PROVIDER}_{key}"


def fetch_series(tag: str, measure: str, start: datetime, end: datetime,
                 get=requests.get) -> dict:
    """{utc datetime: value} for UNIDATA.{tag}.{measure} (FLOW or LEVEL)."""
    response = get(API, params={
        'tagName': f"UNIDATA.{tag}.{measure}",
        'start': format_datetime(start.astimezone(timezone.utc), usegmt=True),
        'end': format_datetime(end.astimezone(timezone.utc), usegmt=True),
    }, timeout=TIMEOUT)
    response.raise_for_status()
    return parse_values(response.json().get('values') or [])


def parse_values(values: list) -> dict:
    out = {}
    for v in values:
        value, time = v.get('value'), v.get('time')
        # Skip NaN/inf (Python's json accepts them) and booleans.
        if (isinstance(value, bool) or not isinstance(value, (int, float))
                or not math.isfinite(value) or not time):
            continue
        try:
            local = datetime.fromisoformat(time)
        except ValueError:
            continue
        if local.tzinfo is None:
            local = local.replace(tzinfo=PACIFIC)
        out[local.astimezone(timezone.utc)] = float(value)
    return out


def combine(flow: dict, level: dict) -> list:
    """Readings oldest first: {datetime, discharge, level}."""
    readings = []
    for t in sorted(set(flow) | set(level)):
        r = {'datetime': t.strftime('%Y-%m-%dT%H:%M:%SZ')}
        if t in flow:
            r['discharge'] = round(flow[t], 3)
        if t in level:
            r['level'] = round(level[t], 3)
        readings.append(r)
    return readings


def to_csv(readings: list) -> str:
    lines = ['datetime,discharge,level']
    for r in readings:
        lines.append(f"{r['datetime']},{r.get('discharge', '')},{r.get('level', '')}")
    return '\n'.join(lines)


def trend(readings: list) -> str:
    """Rising or falling by more than 5% of flow over the last 3 hours."""
    flows = [(r['datetime'], r['discharge']) for r in readings if 'discharge' in r]
    if len(flows) < 2:
        return 'stable'
    latest_time = datetime.fromisoformat(flows[-1][0].replace('Z', '+00:00'))
    cutoff = latest_time - timedelta(hours=3)
    earlier = [f for t, f in flows
               if datetime.fromisoformat(t.replace('Z', '+00:00')) <= cutoff]
    if not earlier:
        return 'stable'
    then, now = earlier[-1], flows[-1][1]
    margin = max(abs(then) * 0.05, 0.1)
    if now > then + margin:
        return 'rising'
    if now < then - margin:
        return 'falling'
    return 'stable'


def fetch_readings(key: str, days: int, now: datetime = None, get=requests.get) -> list:
    now = now or datetime.now(timezone.utc)
    tag = STATIONS[key]['tag']
    start = now - timedelta(days=days)
    return combine(fetch_series(tag, 'FLOW', start, now, get),
                   fetch_series(tag, 'LEVEL', start, now, get))


def update_realtime(db, now: datetime = None, get=requests.get) -> dict:
    """Writes 30 days of readings and the station name for each gauge.

    Returns {doc id: latest discharge} for the flow alerts.
    """
    now = now or datetime.now(timezone.utc)
    flows = {}
    for key, station in STATIONS.items():
        try:
            readings = fetch_readings(key, 30, now, get)
            if not readings:
                logger.warning(f"Metro Vancouver {key}: no readings")
                continue
            latest = readings[-1]
            db.collection('station_current').document(doc_id(key)).set({
                'station_id': key,
                'provider': PROVIDER,
                'latest_reading': latest,
                'trend': trend(readings),
                'hourly_readings_csv': to_csv(readings),
                'updated_at': now,
            })
            db.collection('stations').document(doc_id(key)).set({
                'name': station['name'],
                'stationNumber': key,
                'provider': PROVIDER,
            }, merge=True)
            if latest.get('discharge') is not None:
                flows[doc_id(key)] = latest['discharge']
            logger.info(f"Metro Vancouver {key}: {len(readings)} readings")
        except Exception as e:
            logger.error(f"Metro Vancouver {key} failed: {e}", exc_info=True)
    return flows


def update_daily(store, now: datetime = None, get=requests.get) -> dict:
    """Re-averages each complete Pacific day of the last year.

    [store] is a daily_updater.HistoryStore-like object; history goes under
    the same `station_data/metro_vancouver_{key}` ids.
    """
    import daily_updater  # avoid a cycle at import time

    now = now or datetime.now(timezone.utc)
    results = {}
    for key in STATIONS:
        try:
            readings = fetch_readings(key, 366, now, get)
            means = daily_updater.daily_means(readings, now)
            store.write_daily_doc(doc_id(key), means)
            results[key] = len(means)
        except Exception as e:
            logger.error(f"Metro Vancouver {key} daily failed: {e}", exc_info=True)
            results[key] = f"error: {e}"
    return results
