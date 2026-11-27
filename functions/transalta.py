"""
TransAlta's Kananaskis River dam releases: Barrier and Pocaterra.

TransAlta publishes each plant's planned outflow, hour by hour, for today
and the next four days at
https://transalta.com/our-operations/safety/river-flows. The table is an
Astro "server island": the page carries a script that fetches
/_server-islands/RiverFlowDataTableContents?e=...&p=&s=, and that URL
changes with each TransAlta deploy. So every run reads the page first,
takes the island URL from it, then reads the island's HTML table.

The table's rows are AESO "hour ending" (HE01 is 00:00 to 01:00) in
Alberta time, which is UTC-6 all year since Alberta kept daylight time in
November 2026 (the page says so). 0 m3/s means the plant is off.

Stored like the other gauges so the logbook, charts and alerts work:

- `station_current/transalta_{key}`: `hourly_readings_csv` holds the
  scheduled flow for each hour that has started, kept for 30 days (the
  page only shows today onwards, so this is our own record).
  `release_schedule_csv` holds every published hour from the start of
  today, `start,flow` in UTC, for the app's schedule view.
- `stations/transalta_{key}`: name, latest flow, `kind: 'dam_release'`.
- `station_data/transalta_{key}/readings/{year}`: per Alberta day, the
  flow while the dam was releasing (`mean_discharge`, 0 on days with no
  release), so long charts show release days rather than a 24-hour
  average diluted by the hours it was off.

Runs point at them with `stationId: transalta_barrier` (Lower Kananaskis)
or `transalta_pocaterra` (Upper Kananaskis).
"""

import html as html_lib
import logging
import re
from collections import defaultdict
from datetime import datetime, timedelta, timezone
from html.parser import HTMLParser

import requests

logger = logging.getLogger(__name__)

PROVIDER = 'transalta'
PAGE = 'https://transalta.com/our-operations/safety/river-flows'
ORIGIN = 'https://transalta.com'
# Alberta time. Fixed rather than a tz name: Alberta moved to permanent
# UTC-6 in November 2026 and tz databases may still say UTC-7 in winter.
ALBERTA = timezone(timedelta(hours=-6))
TIMEOUT = 30
KEEP_DAYS = 30
HEADERS = {'User-Agent': 'Brownpaw river gauges (+https://brownclaw.web.app)'}

STATIONS = {
    'barrier': {
        'column': 'Barrier',
        'name': 'Barrier Dam release',
        'note': 'Water takes about 45 minutes from Barrier Dam to Canoe Meadows.',
    },
    'pocaterra': {
        'column': 'Pocaterra',
        'name': 'Pocaterra release',
        'note': None,
    },
}

ISLAND = re.compile(r'/_server-islands/RiverFlowDataTableContents[^"\'`\s<>]*')
DEPLOY_ID = re.compile(r'X-Netlify-Deploy-ID"\s*:\s*"([^"]+)"')
DAY = re.compile(r'([A-Za-z]{3})\s+(\d{1,2})\s*$')
MONTHS = {m: i + 1 for i, m in enumerate(
    'jan feb mar apr may jun jul aug sep oct nov dec'.split())}


def doc_id(key: str) -> str:
    return f"{PROVIDER}_{key}"


class _Table(HTMLParser):
    """Rows of cell text, with colspan, from the first table."""

    def __init__(self):
        super().__init__()
        self.rows, self._row, self._cell, self._span = [], None, None, 1
        self._depth = 0

    def handle_starttag(self, tag, attrs):
        if tag == 'table':
            self._depth += 1
        elif tag == 'tr' and self._depth:
            self._row = []
        elif tag in ('td', 'th') and self._row is not None:
            self._cell = []
            span = dict(attrs).get('colspan') or '1'
            self._span = int(span) if span.isdigit() else 1

    def handle_endtag(self, tag):
        if tag in ('td', 'th') and self._cell is not None:
            self._row.append((' '.join(''.join(self._cell).split()), self._span))
            self._cell = None
        elif tag == 'tr' and self._row is not None:
            self.rows.append(self._row)
            self._row = None
        elif tag == 'table':
            self._depth -= 1

    def handle_data(self, data):
        if self._cell is not None:
            self._cell.append(data)


def island_request(page_html: str):
    """(island URL, extra headers) from the page, or raises ValueError."""
    m = ISLAND.search(page_html)
    if not m:
        raise ValueError('river flow table not found on the TransAlta page')
    path = html_lib.unescape(m.group(0)).replace('\\u0026', '&')
    headers = dict(HEADERS)
    deploy = DEPLOY_ID.search(page_html)
    if deploy:
        headers['X-Netlify-Deploy-ID'] = deploy.group(1)
    return ORIGIN + path, headers


def _date_for(label: str, now: datetime):
    """"Fri, Nov 27" → the date in the year closest to [now]."""
    m = DAY.search(label)
    if not m or m.group(1).lower() not in MONTHS:
        return None
    month, day = MONTHS[m.group(1).lower()], int(m.group(2))
    today = now.astimezone(ALBERTA).date()
    best = None
    for year in (today.year - 1, today.year, today.year + 1):
        try:
            d = today.replace(year=year, month=month, day=day)
        except ValueError:
            continue
        if best is None or abs((d - today).days) < abs((best - today).days):
            best = d
    return best


def parse_table(island_html: str, now: datetime = None) -> dict:
    """{station key: {utc hour start: flow}} from the island's table."""
    now = now or datetime.now(timezone.utc)
    parser = _Table()
    parser.feed(island_html)
    rows = parser.rows
    if len(rows) < 3:
        raise ValueError('river flow table is empty')

    # Row 1: "Hour Ending Time", then one date per colspan-2 group.
    dates = []
    for text, span in rows[0][1:]:
        dates.extend([_date_for(text, now)] * span)
    # Row 2: plant names under each date.
    plants = [text for text, _ in rows[1]]
    if len(plants) != len(dates):
        raise ValueError('river flow table headers don\'t line up')
    columns = {s['column'].lower(): key for key, s in STATIONS.items()}

    out = {key: {} for key in STATIONS}
    for row in rows[2:]:
        cells = [text for text, _ in row]
        if not cells or not cells[0].isdigit():
            continue
        hour_ending = int(cells[0])
        if not 1 <= hour_ending <= 24:
            continue
        for i, value in enumerate(cells[1:]):
            if i >= len(plants) or dates[i] is None:
                continue
            key = columns.get(plants[i].strip().lower())
            if key is None:
                continue
            try:
                flow = float(value.replace(',', ''))
            except ValueError:
                continue
            start = datetime(dates[i].year, dates[i].month, dates[i].day,
                             tzinfo=ALBERTA) + timedelta(hours=hour_ending - 1)
            out[key][start.astimezone(timezone.utc)] = flow
    if not any(out.values()):
        raise ValueError('no flows in the river flow table')
    return out


def fetch_schedule(get=requests.get, now: datetime = None) -> dict:
    """{station key: {utc hour start: flow}} for today and the next days."""
    page = get(PAGE, headers=HEADERS, timeout=TIMEOUT)
    page.raise_for_status()
    url, headers = island_request(page.text)
    island = get(url, headers=headers, timeout=TIMEOUT)
    island.raise_for_status()
    return parse_table(island.text, now)


def _iso(t: datetime) -> str:
    return t.astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def _parse_iso(s: str):
    try:
        return datetime.fromisoformat(s.replace('Z', '+00:00'))
    except ValueError:
        return None


def parse_history(csv: str) -> dict:
    """{utc datetime: discharge} from a stored `hourly_readings_csv`."""
    out = {}
    for line in (csv or '').splitlines()[1:]:
        parts = line.split(',')
        if len(parts) < 2 or not parts[1]:
            continue
        t = _parse_iso(parts[0])
        try:
            out[t] = float(parts[1])
        except (TypeError, ValueError):
            continue
    out.pop(None, None)
    return out


def merge_history(stored: dict, schedule: dict, now: datetime) -> dict:
    """Started hours: the stored record, overwritten by the latest
    schedule for hours it covers, trimmed to the last [KEEP_DAYS]."""
    cutoff = now - timedelta(days=KEEP_DAYS)
    merged = {t: f for t, f in stored.items() if cutoff <= t <= now}
    merged.update({t: f for t, f in schedule.items() if cutoff <= t <= now})
    return merged


def history_csv(points: dict) -> str:
    lines = ['datetime,discharge,level']
    for t, f in sorted(points.items()):
        lines.append(f"{_iso(t)},{f:g},")
    return '\n'.join(lines)


def schedule_csv(schedule: dict, now: datetime) -> str:
    """Published hours from the start of today (Alberta), oldest first."""
    today = now.astimezone(ALBERTA).replace(hour=0, minute=0, second=0,
                                           microsecond=0)
    lines = ['start,flow']
    for t, f in sorted(schedule.items()):
        if t >= today:
            lines.append(f"{_iso(t)},{f:g}")
    return '\n'.join(lines)


def trend(points: dict, now: datetime) -> str:
    """Rising when the release is ramping up in the last 3 hours."""
    started = sorted((t, f) for t, f in points.items() if t <= now)
    if len(started) < 2:
        return 'stable'
    latest_t, latest = started[-1]
    earlier = [f for t, f in started if t <= latest_t - timedelta(hours=3)]
    then = earlier[-1] if earlier else started[0][1]
    if latest > then:
        return 'rising'
    if latest < then:
        return 'falling'
    return 'stable'


def daily_release(points: dict) -> dict:
    """Per complete-or-current Alberta day: the mean flow over the hours
    the dam was releasing (0 when it didn't release)."""
    by_day = defaultdict(list)
    for t, f in points.items():
        by_day[t.astimezone(ALBERTA).date()].append(f)
    out = {}
    for day, flows in by_day.items():
        on = [f for f in flows if f > 0]
        out[day.isoformat()] = {
            'mean_discharge': round(sum(on) / len(on), 2) if on else 0.0,
            'release_hours': len(on),
        }
    return out


def update_realtime(db, now: datetime = None, get=requests.get) -> dict:
    """Reads the schedule and writes both stations.

    Returns {doc id: current flow} for the flow alerts.
    """
    now = now or datetime.now(timezone.utc)
    try:
        schedule = fetch_schedule(get, now)
    except Exception as e:
        logger.error(f"TransAlta schedule failed: {e}", exc_info=True)
        return {}

    flows = {}
    for key, station in STATIONS.items():
        hours = schedule.get(key) or {}
        if not hours:
            logger.warning(f"TransAlta {key}: no hours in the schedule")
            continue
        try:
            ref = db.collection('station_current').document(doc_id(key))
            previous = ref.get()
            stored = parse_history(
                (previous.to_dict() or {}).get('hourly_readings_csv', '')
                if previous.exists else '')
            history = merge_history(stored, hours, now)
            latest_t = max(history) if history else None
            latest = ({'datetime': _iso(latest_t), 'discharge': history[latest_t]}
                      if latest_t else None)
            ref.set({
                'station_id': key,
                'provider': PROVIDER,
                'kind': 'dam_release',
                'latest_reading': latest,
                'trend': trend(history, now),
                'hourly_readings_csv': history_csv(history),
                'release_schedule_csv': schedule_csv(hours, now),
                'schedule_updated_at': now,
                'updated_at': now,
            })
            summary = {
                'name': station['name'],
                'stationNumber': key,
                'provider': PROVIDER,
                'kind': 'dam_release',
                'flow': latest['discharge'] if latest else None,
                'readingTime': latest['datetime'] if latest else None,
            }
            if station['note']:
                summary['note'] = station['note']
            db.collection('stations').document(doc_id(key)).set(
                summary, merge=True)
            if latest is not None:
                flows[doc_id(key)] = latest['discharge']
            logger.info(f"TransAlta {key}: {len(hours)} scheduled hours")
        except Exception as e:
            logger.error(f"TransAlta {key} failed: {e}", exc_info=True)
    return flows


def update_daily(store, db, now: datetime = None) -> dict:
    """Daily release flows from our stored record (TransAlta keeps none)."""
    now = now or datetime.now(timezone.utc)
    results = {}
    for key in STATIONS:
        try:
            doc = db.collection('station_current').document(doc_id(key)).get()
            points = parse_history(
                (doc.to_dict() or {}).get('hourly_readings_csv', '')
                if doc.exists else '')
            daily = daily_release(points)
            store.write_daily_doc(doc_id(key), daily)
            results[key] = len(daily)
        except Exception as e:
            logger.error(f"TransAlta {key} daily failed: {e}", exc_info=True)
            results[key] = f"error: {e}"
    return results
