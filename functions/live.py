"""Live readings straight from each gauge's source, for the app.

The app reads the last 30 days live (current flow, 2-day/2-week/1-month
charts) and uses the Firestore copy only as a fallback. Browsers can't
call some sources directly (no CORS), so the app asks this function, which
Firebase Hosting serves at /api/live on the app's own domain:

    /api/live?station=environment_canada_08HA011&hours=6

`hours` is how far back (1 to 720); the app asks only for what its stored
copy is missing, rounded to a few sizes so the CDN can share responses.
Replies are `datetime,discharge,level` CSV, oldest first, cached for 5
minutes.
"""

import asyncio
import math
import re

import flowworks
import metro_vancouver

EC_ID = re.compile(r'^environment_canada_(\d{2}[A-Z]{2}\d{3})$')
MAX_HOURS = 720


def parse_request(station: str, hours: str):
    """(provider, key, hours) or raises ValueError."""
    try:
        h = int(hours or 24)
    except ValueError:
        raise ValueError('hours must be a number')
    h = max(1, min(MAX_HOURS, h))
    station = (station or '').strip()
    m = EC_ID.match(station)
    if m:
        return 'environment_canada', m.group(1), h
    for key in metro_vancouver.STATIONS:
        if station == metro_vancouver.doc_id(key):
            return 'metro_vancouver', key, h
    if station == flowworks.DOC_ID:
        return 'flowworks', flowworks.STATION, h
    raise ValueError(f'unknown station {station!r}')


def to_csv(readings: list) -> str:
    """Oldest first, finite numbers only."""
    def num(v):
        return f'{v}' if isinstance(v, (int, float)) and math.isfinite(v) else ''
    rows = sorted(
        (r for r in readings if r.get('datetime')),
        key=lambda r: r['datetime'],
    )
    lines = ['datetime,discharge,level']
    for r in rows:
        lines.append(f"{r['datetime']},{num(r.get('discharge'))},{num(r.get('level'))}")
    return '\n'.join(lines)


async def _environment_canada(code: str, hours: int) -> list:
    from scripts.environment_canada.realtime_data_service import RealtimeDataService
    async with RealtimeDataService() as service:
        return await service.fetch_latest_readings(code, hours=hours)


def fetch(provider: str, key: str, hours: int) -> list:
    days = max(1, math.ceil(hours / 24))
    if provider == 'environment_canada':
        return asyncio.run(_environment_canada(key, hours))
    if provider == 'metro_vancouver':
        return metro_vancouver.fetch_readings(key, days)
    return flowworks.to_readings(flowworks.fetch_points(days))
