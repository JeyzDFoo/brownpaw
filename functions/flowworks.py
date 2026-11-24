"""
Lynn Creek at the Trans-Canada Highway bridge.

The District of North Vancouver publishes this gauge through Flowworks.
The Vancouver Whitewater Club's Lynn level page reads it with a public
v1 URL (site 183, channel 674, flow in m3/s). Times come back as Pacific
local time with no offset. Readings are about every 5 minutes.
`intervaltype/D/intervalnum/{days}` is that many days of the native series.

This is a stopgap until the District issues a login of our own. The URL
is the one already published in the club page's script.

Stored like the other gauges, under `station_current/flowworks_lynn` and
`station_data/flowworks_lynn/readings/{year}`. The run points at it with
`stationId: flowworks_lynn`.
"""

import logging
from collections import defaultdict
from datetime import datetime, timedelta, timezone

import requests

logger = logging.getLogger(__name__)

PROVIDER = 'flowworks'
STATION = 'lynn'
DOC_ID = f'{PROVIDER}_{STATION}'
NAME = 'Lynn Creek at Trans-Canada Highway Bridge'
PDT = timezone(timedelta(hours=-7))
PST = timezone(timedelta(hours=-8))
# Public read URL from the club's Lynn level page.
API = ('https://developers.flowworks.com/fwapi/v1/'
       'f4cd7030-8d34-4d32-9833-22ed7490a44c')
SITE = 183
CHANNEL = 674
TIMEOUT = 60


def _nth_sunday(year: int, month: int, n: int) -> datetime:
    first = datetime(year, month, 1)
    day = 1 + (6 - first.weekday()) % 7 + 7 * (n - 1)
    return datetime(year, month, day, 2)


def as_pacific(local: datetime) -> datetime:
    """Wall time in Vancouver as an aware datetime.

    PDT (UTC-7) runs from 02:00 on the second Sunday in March until 02:00
    on the first Sunday in November. The rest of the year is PST (UTC-8).
    Spelled out here because the tz database on some machines keeps
    Vancouver on UTC-7 through the winter.
    """
    if local.tzinfo is not None:
        local = local.replace(tzinfo=None)
    start = _nth_sunday(local.year, 3, 2)
    end = _nth_sunday(local.year, 11, 1)
    offset = PDT if start <= local < end else PST
    return local.replace(tzinfo=offset)


def fetch_points(days: int, get=requests.get) -> dict:
    """{utc datetime: discharge} for the last [days] days."""
    response = get(
        f"{API}/site/{SITE}/channel/{CHANNEL}/data/intervaltype/D/intervalnum/{days}",
        timeout=TIMEOUT,
    )
    response.raise_for_status()
    body = response.json()
    if body.get('requeststatus') != 1:
        raise RuntimeError(body.get('msg') or 'Flowworks request failed')
    return parse_points(body.get('datapoints') or [])


def parse_points(points: list) -> dict:
    out = {}
    for point in points:
        value, date = point.get('value'), point.get('date')
        if not isinstance(value, (int, float)) or not date:
            continue
        try:
            local = datetime.fromisoformat(date)
        except ValueError:
            continue
        out[as_pacific(local).astimezone(timezone.utc)] = float(value)
    return out


def to_readings(points: dict) -> list:
    """Readings oldest first: {datetime, discharge}."""
    return [
        {
            'datetime': t.strftime('%Y-%m-%dT%H:%M:%SZ'),
            'discharge': round(value, 3),
        }
        for t, value in sorted(points.items())
    ]


def to_csv(readings: list) -> str:
    lines = ['datetime,discharge,level']
    for r in readings:
        lines.append(f"{r['datetime']},{r.get('discharge', '')},")
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


def update_realtime(db, now: datetime = None, get=requests.get) -> dict:
    """Writes 30 days of readings and the station name.

    Returns {doc id: latest discharge} for the flow alerts.
    """
    now = now or datetime.now(timezone.utc)
    try:
        readings = to_readings(fetch_points(30, get))
    except Exception as e:
        logger.error(f"Flowworks Lynn Creek failed: {e}", exc_info=True)
        return {}
    if not readings:
        logger.warning('Flowworks Lynn Creek: no readings')
        return {}
    latest = readings[-1]
    db.collection('station_current').document(DOC_ID).set({
        'station_id': STATION,
        'provider': PROVIDER,
        'latest_reading': latest,
        'trend': trend(readings),
        'hourly_readings_csv': to_csv(readings),
        'updated_at': now,
    })
    db.collection('stations').document(DOC_ID).set({
        'name': NAME,
        'stationNumber': STATION,
        'provider': PROVIDER,
    }, merge=True)
    logger.info(f"Flowworks Lynn Creek: {len(readings)} readings")
    if latest.get('discharge') is None:
        return {}
    return {DOC_ID: latest['discharge']}


def to_pacific(utc: datetime) -> datetime:
    """The Vancouver wall time for a UTC instant."""
    if utc.tzinfo is None:
        utc = utc.replace(tzinfo=timezone.utc)
    utc = utc.astimezone(timezone.utc).replace(microsecond=0)
    for offset in (PDT, PST):
        wall = as_pacific(utc.astimezone(offset).replace(tzinfo=None))
        if wall.astimezone(timezone.utc).replace(microsecond=0) == utc:
            return wall
    return utc.astimezone(PST)


def complete_daily_means(readings: list, now: datetime) -> dict:
    """Mean discharge for each complete Pacific day.

    Today is left out, and so is the earliest day, which the window cuts
    part way through.
    """
    today = to_pacific(now).date()
    by_day = defaultdict(list)
    for reading in readings:
        try:
            instant = datetime.fromisoformat(reading['datetime'].replace('Z', '+00:00'))
        except (KeyError, ValueError):
            continue
        if reading.get('discharge') is None:
            continue
        by_day[to_pacific(instant).date()].append(reading['discharge'])
    if not by_day:
        return {}
    first = min(by_day)
    return {
        day.isoformat(): {'mean_discharge': round(sum(values) / len(values), 2)}
        for day, values in by_day.items()
        if day != first and day < today and values
    }


def update_daily(store, now: datetime = None, get=requests.get) -> dict:
    """Re-averages each complete Pacific day of the last year."""
    now = now or datetime.now(timezone.utc)
    try:
        readings = to_readings(fetch_points(366, get))
        means = complete_daily_means(readings, now)
        store.write_daily_doc(DOC_ID, means)
        return {STATION: len(means)}
    except Exception as e:
        logger.error(f"Flowworks Lynn Creek daily failed: {e}", exc_info=True)
        return {STATION: f"error: {e}"}
