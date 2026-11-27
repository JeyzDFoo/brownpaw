"""
Tidal play spots: Skookumchuck Narrows (Sechelt Rapids), so far.

A tidal wave has no gauge to read. What paddlers plan on is the predicted
current: when each flood peaks and how fast (the Skook waves are flood
features), and when the water goes slack. Plus the tide height nearby.

- Currents come from Jeff Dairiki's XTide tables, which the Skook surfing
  community uses (skooksurfing.com's calendar is built on them):
  https://www.dairiki.org/tides/monthly.php/scl/YYYY-MM. One month per page,
  rows of slack ("turn") times and max flood (F) / ebb (E) times and knots,
  in the zone the page names (MST, i.e. UTC-7, the same as BC now).
  If Dairiki can't be read, the Canadian Hydrographic Service's own
  Sechelt Rapids predictions (IWLS `wcp1-events`) stand in.
- Tide heights come from CHS IWLS high/low predictions at Egmont
  (`wlp-hilo`, metres above chart datum).

Predictions don't change, so the pages are read at most twice a day; the
hourly run only re-derives the latest reading from what's stored.

Stored like the other gauges, so the logbook, alerts and lists work:

- `station_current/tidal_sechelt_rapids`:
  `current_events_csv` (`time,kind,knots`, kind slack/flood/ebb, UTC),
  `tide_events_csv` (`time,kind,metres`, kind high/low), `current_source`.
  `hourly_readings_csv`'s discharge column holds, for each hour of the last
  30 days, the max flood (knots) of the flood nearest that hour, which is
  how paddlers name a Skook session ("we surfed 12 knots"). So a descent
  logged at Skook records its knots.
- `stations/tidal_sechelt_rapids`: name, kind 'tidal', next max flood in
  daylight (also what flow alerts check).
- `station_data/tidal_sechelt_rapids/readings/{year}`: per Pacific day,
  the biggest max flood in daylight (`mean_discharge`).

Runs point at it with `stationId: tidal_sechelt_rapids`, `flowUnit: kt`.
"""

import logging
import math
import re
from datetime import date, datetime, timedelta, timezone
from html.parser import HTMLParser

import requests

logger = logging.getLogger(__name__)

PROVIDER = 'tidal'
# BC is on permanent UTC-7 (2026). Fixed, like transalta.ALBERTA, because
# tz databases may still say UTC-8 in winter.
PACIFIC = timezone(timedelta(hours=-7))
TIMEOUT = 30
KEEP_DAYS = 30
REFRESH = timedelta(hours=12)
HEADERS = {'User-Agent': 'Brownpaw river gauges (+https://brownclaw.web.app)'}

DAIRIKI = 'https://www.dairiki.org/tides/monthly.php/{code}/{year:04d}-{month:02d}'
IWLS = 'https://api-iwls.dfo-mpo.gc.ca/api/v1/stations/{id}/data'

STATIONS = {
    'sechelt_rapids': {
        'name': 'Sechelt Rapids',
        'dairiki': 'scl',
        'chs_current': '63aef40a6a2b9417c0350313',  # 07845 Sechelt Rapids
        'chs_tide': '5dd3064ee0fdc4b9b4be670d',  # 07842 Egmont
        'tide_name': 'Egmont',
        'lat': 49.7383,
        'lon': -123.8983,
        'note': 'Currents from dairiki.org (XTide), tides at Egmont from '
                'the Canadian Hydrographic Service. Predictions, not '
                'measurements.',
    },
}

ZONES = {'UTC': 0, 'GMT': 0, 'PST': -8, 'PDT': -7, 'MST': -7, 'MDT': -6}
TIME = re.compile(r'^(\d{1,2}):(\d{2})$')
VALUE = re.compile(r'^(-?\d+(?:\.\d+)?)\s*([EF])$')
DATE_HREF = re.compile(r'(\d{4})-(\d{2})-(\d{2})')
ZONE = re.compile(r'Time Zone is\s+([A-Z]{3,4})')


def doc_id(key: str) -> str:
    return f"{PROVIDER}_{key}"


# --- Dairiki -------------------------------------------------------------

class _Rows(HTMLParser):
    """Each <tr> as (date or None, [(cell class, text)])."""

    def __init__(self):
        super().__init__()
        self.rows = []
        self.text = []
        self._row = None
        self._cell = None
        self._date = None

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag == 'tr':
            self._row = []
            self._date = None
        elif tag in ('td', 'th') and self._row is not None:
            self._cell = [a.get('class') or '', '']
        elif tag == 'a' and self._cell is not None:
            m = DATE_HREF.search(a.get('href') or '')
            if m and 'daily' in (a.get('href') or ''):
                self._date = date(*map(int, m.groups()))
        elif tag == 'span' and self._cell is not None:
            # The moon-phase glyph after the date isn't data.
            self._cell.append('skip')

    def handle_endtag(self, tag):
        if tag == 'span' and self._cell is not None and self._cell[-1] == 'skip':
            self._cell.pop()
        elif tag in ('td', 'th') and self._cell is not None:
            self._row.append((self._cell[0], self._cell[1].strip()))
            self._cell = None
        elif tag == 'tr' and self._row is not None:
            self.rows.append((self._date, self._row))
            self._row = None

    def handle_data(self, data):
        self.text.append(data)
        if self._cell is not None and self._cell[-1] != 'skip':
            self._cell[1] += data


def parse_dairiki(page: str) -> list:
    """[(utc datetime, kind, knots)] from one monthly current table,
    oldest first. kind is 'slack', 'flood' or 'ebb'; knots are unsigned."""
    p = _Rows()
    p.feed(page)
    zone = ZONE.search(' '.join(p.text))
    if not zone or zone.group(1) not in ZONES:
        raise ValueError(f"Unknown time zone: {zone.group(1) if zone else None}")
    tz = timezone(timedelta(hours=ZONES[zone.group(1)]))
    events = []
    day = None
    for row_date, cells in p.rows:
        if row_date:
            day = row_date
        if day is None:
            continue
        pending = None  # a max time waiting for its value
        for cls, text in cells:
            classes = cls.split()
            if 'first' in classes or 'empty' in classes or not text:
                continue
            t = TIME.match(text)
            v = VALUE.match(text)
            if 'left' in classes and t:
                pending = _at(day, t, tz)
            elif 'right' in classes and v and pending is not None:
                knots = abs(float(v.group(1)))
                kind = 'flood' if v.group(2) == 'F' else 'ebb'
                events.append((pending, kind, knots))
                pending = None
            elif t:
                events.append((_at(day, t, tz), 'slack', 0.0))
    events.sort(key=lambda e: e[0])
    return events


def _at(day: date, m, tz) -> datetime:
    h, mi = int(m.group(1)), int(m.group(2))
    local = datetime(day.year, day.month, day.day, tzinfo=tz)
    return (local + timedelta(hours=h, minutes=mi)).astimezone(timezone.utc)


def _months(now: datetime, ahead: int = 2):
    """(year, month) for this Pacific month and the next [ahead]-1, plus
    last month while it's early in this one (for the 30-day history)."""
    local = now.astimezone(PACIFIC)
    y, m = local.year, local.month
    out = []
    if local.day <= KEEP_DAYS:
        out.append((y - 1, 12) if m == 1 else (y, m - 1))
    for i in range(ahead):
        mm = m + i
        out.append((y + (mm - 1) // 12, (mm - 1) % 12 + 1))
    return out


def fetch_dairiki(code: str, now: datetime, get=requests.get) -> list:
    events = {}
    for y, m in _months(now):
        r = get(DAIRIKI.format(code=code, year=y, month=m), headers=HEADERS,
                timeout=TIMEOUT)
        r.raise_for_status()
        for e in parse_dairiki(r.text):
            events[e[0]] = e
    return [events[t] for t in sorted(events)]


# --- CHS IWLS --------------------------------------------------------------

def _iwls(station: str, series: str, start: datetime, end: datetime,
          get=requests.get) -> list:
    """IWLS rows in 7-day requests (the API caps a request's span)."""
    rows = []
    t = start
    while t < end:
        stop = min(t + timedelta(days=7), end)
        r = get(IWLS.format(id=station), headers=HEADERS, timeout=TIMEOUT,
                params={'time-series-code': series, 'from': _iso(t),
                        'to': _iso(stop)})
        r.raise_for_status()
        rows.extend(r.json())
        t = stop
    return rows


def _window(now: datetime):
    return now - timedelta(days=KEEP_DAYS + 1), now + timedelta(days=45)


def fetch_chs_currents(station: str, now: datetime, get=requests.get) -> list:
    kinds = {'EXTREMA_FLOOD': 'flood', 'EXTREMA_EBB': 'ebb', 'SLACK': 'slack'}
    out = {}
    for row in _iwls(station, 'wcp1-events', *_window(now), get=get):
        t = _parse_iso(row.get('eventDate', ''))
        kind = kinds.get(row.get('qualifier'))
        if t and kind:
            out[t] = (t, kind, abs(float(row.get('value') or 0)))
    return [out[t] for t in sorted(out)]


def fetch_tides(station: str, now: datetime, get=requests.get) -> list:
    """[(utc, 'high'|'low', metres)]: each turn of the tide, labelled by
    comparing it with its neighbours."""
    pts = {}
    for row in _iwls(station, 'wlp-hilo', *_window(now), get=get):
        t = _parse_iso(row.get('eventDate', ''))
        if t and row.get('value') is not None:
            pts[t] = float(row['value'])
    times = sorted(pts)
    out = []
    for i, t in enumerate(times):
        v = pts[t]
        near = [pts[times[j]] for j in (i - 1, i + 1) if 0 <= j < len(times)]
        high = all(v > n for n in near) if near else v > 2.5
        out.append((t, 'high' if high else 'low', v))
    return out


# --- Derived values --------------------------------------------------------

def floods(events: list) -> list:
    return [e for e in events if e[1] == 'flood']


def nearest_flood(events: list, t: datetime):
    fl = floods(events)
    if not fl:
        return None
    return min(fl, key=lambda e: abs((e[0] - t).total_seconds()))


def next_flood(events: list, now: datetime):
    for e in floods(events):
        if e[0] >= now:
            return e
    return None


def is_daylight(t: datetime, lat: float, lon: float) -> bool:
    """First to last light (civil twilight), give or take half an hour:
    the wave runs for a while either side of the peak. Matches the app's
    isDaylight (lib/domain/tidal.dart)."""
    dawn, dusk = sun_times(t.astimezone(PACIFIC).date(), lat, lon, altitude=-6)
    grace = timedelta(minutes=30)
    return dawn - grace <= t <= dusk + grace


def next_daylight_flood(events: list, now: datetime, lat: float, lon: float):
    for e in floods(events):
        if e[0] >= now and is_daylight(e[0], lat, lon):
            return e
    return None


def sun_times(day: date, lat: float, lon: float, altitude: float = -0.833):
    """(sunrise, sunset) in UTC for [day], NOAA's simple equation; good
    to a couple of minutes, which is all a "flood in daylight" needs."""
    n = day.toordinal() - date(2000, 1, 1).toordinal()
    jstar = n - 0.0008 - lon / 360.0
    m = math.radians((357.5291 + 0.98560028 * jstar) % 360)
    c = 1.9148 * math.sin(m) + 0.02 * math.sin(2 * m) + 0.0003 * math.sin(3 * m)
    lam = math.radians((math.degrees(m) + c + 180 + 102.9372) % 360)
    transit = 2451545.0 + jstar + 0.0053 * math.sin(m) - 0.0069 * math.sin(2 * lam)
    decl = math.asin(math.sin(lam) * math.sin(math.radians(23.4397)))
    phi = math.radians(lat)
    cos_w = ((math.sin(math.radians(altitude)) - math.sin(phi) * math.sin(decl))
             / (math.cos(phi) * math.cos(decl)))
    w = math.degrees(math.acos(max(-1.0, min(1.0, cos_w))))

    def at(jd):
        return datetime(2000, 1, 1, 12, tzinfo=timezone.utc) + timedelta(
            days=jd - 2451545.0)

    return at(transit - w / 360.0), at(transit + w / 360.0)


def daylight_floods(events: list, lat: float, lon: float) -> dict:
    """{Pacific day iso: biggest max flood in daylight, knots}."""
    out = {}
    for t, _, knots in floods(events):
        if is_daylight(t, lat, lon):
            key = t.astimezone(PACIFIC).date().isoformat()
            out[key] = max(out.get(key, 0.0), knots)
    return out


def hourly_history(events: list, now: datetime) -> dict:
    """{hour: max flood of the nearest flood} for the last 30 days."""
    start = (now - timedelta(days=KEEP_DAYS)).replace(minute=0, second=0,
                                                     microsecond=0)
    out = {}
    t = start
    while t <= now:
        f = nearest_flood(events, t)
        if f is not None:
            out[t] = f[2]
        t += timedelta(hours=1)
    return out


# --- CSV -------------------------------------------------------------------

def _iso(t: datetime) -> str:
    return t.astimezone(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')


def _parse_iso(s: str):
    try:
        t = datetime.fromisoformat(s.replace('Z', '+00:00'))
    except (ValueError, AttributeError):
        return None
    return t if t.tzinfo else t.replace(tzinfo=timezone.utc)


def events_csv(events: list, header: str) -> str:
    lines = [header]
    for t, kind, v in events:
        lines.append(f"{_iso(t)},{kind},{v:g}")
    return '\n'.join(lines)


def parse_events_csv(csv: str) -> list:
    out = []
    for line in (csv or '').splitlines()[1:]:
        parts = line.strip().split(',')
        if len(parts) < 3:
            continue
        t = _parse_iso(parts[0])
        try:
            v = float(parts[2])
        except ValueError:
            continue
        if t:
            out.append((t, parts[1], v))
    return out


def history_csv(points: dict) -> str:
    lines = ['datetime,discharge,level']
    for t, f in sorted(points.items()):
        lines.append(f"{_iso(t)},{f:g},")
    return '\n'.join(lines)


# --- Jobs ------------------------------------------------------------------

def _due(stored: dict, now: datetime) -> bool:
    fetched = stored.get('events_fetched_at')
    if isinstance(fetched, str):
        fetched = _parse_iso(fetched)
    if not fetched or now - fetched > REFRESH:
        return True
    events = parse_events_csv(stored.get('current_events_csv', ''))
    return not events or events[-1][0] < now + timedelta(days=21)


def refresh(station: dict, now: datetime, get=requests.get):
    """(current events, source, tide events), reading the sources."""
    events, source = [], None
    try:
        events = fetch_dairiki(station['dairiki'], now, get)
        source = 'dairiki'
    except Exception as e:
        logger.warning(f"Dairiki {station['dairiki']} failed: {e}")
    if not events:
        events = fetch_chs_currents(station['chs_current'], now, get)
        source = 'chs'
    tides = []
    try:
        tides = fetch_tides(station['chs_tide'], now, get)
    except Exception as e:
        logger.warning(f"CHS tides {station['tide_name']} failed: {e}")
    return events, source, tides


def update_realtime(db, now: datetime = None, get=requests.get) -> dict:
    """Refreshes predictions when due and writes each station.

    Returns {doc id: next max flood, knots} for the flow alerts.
    """
    now = now or datetime.now(timezone.utc)
    flows = {}
    for key, station in STATIONS.items():
        try:
            ref = db.collection('station_current').document(doc_id(key))
            snap = ref.get()
            stored = (snap.to_dict() or {}) if snap.exists else {}
            doc = {}
            if _due(stored, now):
                events, source, tides = refresh(station, now, get)
                doc.update({
                    'current_events_csv': events_csv(events, 'time,kind,knots'),
                    'current_source': source,
                    'events_fetched_at': now,
                })
                if tides:
                    doc['tide_events_csv'] = events_csv(tides, 'time,kind,metres')
                    doc['tide_station'] = station['tide_name']
            else:
                events = parse_events_csv(stored.get('current_events_csv', ''))
            if not events:
                logger.warning(f"Tidal {key}: no current predictions")
                continue
            history = hourly_history(events, now)
            latest_t = max(history) if history else None
            # What a paddler would go for: the next flood in daylight.
            nxt = (next_daylight_flood(events, now, station['lat'],
                                       station['lon'])
                   or next_flood(events, now))
            doc.update({
                'station_id': key,
                'provider': PROVIDER,
                'kind': 'tidal',
                'latest_reading': ({'datetime': _iso(latest_t),
                                    'discharge': history[latest_t]}
                                   if latest_t else None),
                'trend': 'stable',
                'hourly_readings_csv': history_csv(history),
                'updated_at': now,
            })
            ref.set(doc, merge=True)
            db.collection('stations').document(doc_id(key)).set({
                'name': station['name'],
                'stationNumber': key,
                'provider': PROVIDER,
                'kind': 'tidal',
                'flow': nxt[2] if nxt else None,
                'readingTime': _iso(nxt[0]) if nxt else None,
                'note': station['note'],
            }, merge=True)
            if nxt:
                flows[doc_id(key)] = nxt[2]
            logger.info(f"Tidal {key}: {len(events)} current events")
        except Exception as e:
            logger.error(f"Tidal {key} failed: {e}", exc_info=True)
    return flows


def update_daily(store, db, now: datetime = None) -> dict:
    """Each past Pacific day's biggest daylight flood, for long charts and
    logging old descents."""
    now = now or datetime.now(timezone.utc)
    today = now.astimezone(PACIFIC).date().isoformat()
    results = {}
    for key, station in STATIONS.items():
        try:
            snap = db.collection('station_current').document(doc_id(key)).get()
            events = parse_events_csv(
                (snap.to_dict() or {}).get('current_events_csv', '')
                if snap.exists else '')
            daily = {
                d: {'mean_discharge': k}
                for d, k in daylight_floods(events, station['lat'],
                                            station['lon']).items()
                if d < today
            }
            store.write_daily_doc(doc_id(key), daily)
            results[key] = len(daily)
        except Exception as e:
            logger.error(f"Tidal {key} daily failed: {e}", exc_info=True)
            results[key] = f"error: {e}"
    return results
