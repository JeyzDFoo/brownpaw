"""
Environment Canada's Water Office real-time archive.

HYDAT (the daily-mean API) only holds approved data, months to years
behind; the realtime API only holds the last 30 days. Between them sits
a gap, from a few months (08GA072) to well over a year (08HD006). The
Water Office keeps about 18 months of 5-minute readings, provisional and
final, behind a CSV service:

    https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline
        ?stations[]=08GA072&parameters[]=47&parameters[]=46
        &start_date=2026-07-01 00:00:00&end_date=2026-08-01 00:00:00

Parameter 47 is discharge (m3/s), 46 is level (m). Times are UTC. A month
for one station is about 1 MB. Days older than the archive's ~18 months
can't be recovered from Environment Canada until HYDAT catches up.
"""

import csv
import io
import logging
from collections import defaultdict
from datetime import date, datetime, time, timedelta, timezone
from zoneinfo import ZoneInfo

import requests

logger = logging.getLogger(__name__)

URL = 'https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline'
PACIFIC = ZoneInfo('America/Vancouver')
ARCHIVE_DAYS = 548  # ~18 months
CHUNK_DAYS = 31
TIMEOUT = 60
DISCHARGE, LEVEL = '47', '46'


def _query(code: str, start: datetime, end: datetime) -> list:
    fmt = '%Y-%m-%d %H:%M:%S'
    return [
        ('stations[]', code),
        ('parameters[]', DISCHARGE),
        ('parameters[]', LEVEL),
        ('start_date', start.astimezone(timezone.utc).strftime(fmt)),
        ('end_date', end.astimezone(timezone.utc).strftime(fmt)),
    ]


def accumulate(text: str, sums: dict):
    """Adds each CSV row to sums[pacific day][param] = [total, count]."""
    reader = csv.reader(io.StringIO(text))
    next(reader, None)  # header
    for row in reader:
        if len(row) < 4 or row[2] not in (DISCHARGE, LEVEL) or not row[3]:
            continue
        try:
            t = datetime.fromisoformat(row[1].replace('Z', '+00:00'))
            value = float(row[3])
        except ValueError:
            continue
        if t.tzinfo is None:
            t = t.replace(tzinfo=timezone.utc)
        day = t.astimezone(PACIFIC).date()
        cell = sums[day].setdefault(row[2], [0.0, 0])
        cell[0] += value
        cell[1] += 1


def means(sums: dict) -> dict:
    out = {}
    for day, params in sums.items():
        mean = {}
        if DISCHARGE in params:
            total, n = params[DISCHARGE]
            mean['mean_discharge'] = round(total / n, 2)
        if LEVEL in params:
            total, n = params[LEVEL]
            mean['mean_level'] = round(total / n, 3)
        if mean:
            out[day.isoformat()] = mean
    return out


def daily_means(code: str, after: date = None, now: datetime = None,
                get=requests.get) -> dict:
    """Daily means for each complete Pacific day after [after] (or as far
    back as the archive goes) up to yesterday, keyed `yyyy-MM-dd`."""
    now = now or datetime.now(timezone.utc)
    today = now.astimezone(PACIFIC).date()
    first = today - timedelta(days=ARCHIVE_DAYS)
    if after is not None:
        first = max(first, after + timedelta(days=1))
    if first >= today:
        return {}

    sums = defaultdict(dict)
    day = first
    while day < today:
        until = min(day + timedelta(days=CHUNK_DAYS), today)
        start = datetime.combine(day, time(), PACIFIC)
        # The service includes end_date; stop a second short of midnight.
        end = datetime.combine(until, time(), PACIFIC) - timedelta(seconds=1)
        response = get(URL, params=_query(code, start, end), timeout=TIMEOUT)
        response.raise_for_status()
        accumulate(response.text, sums)
        day = until
    return {k: v for k, v in means(sums).items()
            if first.isoformat() <= k < today.isoformat()}
