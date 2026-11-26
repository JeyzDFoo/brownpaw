#!/usr/bin/env python3
"""Put run info the app needs into Firestore. Safe to run any number of
times: it only writes what's missing or different.

    python3 scripts/sync_run_data.py            # dry run: shows what would change
    python3 scripts/sync_run_data.py --apply

What it writes on each `river_runs/{id}`:

- `flowRanges`: low / medium / high flows from
  scripts/bcwhitewater/flow_ranges.json (unit "cms" or "m"; low, medium,
  high, max are where each level starts, any may be left out; station or
  gauge says which gauge; note and source credit where it came from).
  After the first run, edit a run's flowRanges in the Firebase console
  and the app shows it straight away. Re-running this overwrites a run's
  flowRanges only if it differs from the JSON, so keep the JSON in step
  (or pass --keep-edits to leave runs that already have flowRanges alone).
- `starter: true` on the runs a new paddler starts with starred
  (Capilano, Lynn Creek, the Mamquam).

Needs firebase-service-account.json in the repo folder.
"""

import json
import os
import re
import sys

import firebase_admin
from firebase_admin import credentials, firestore

HERE = os.path.dirname(os.path.abspath(__file__))
RANGES = os.path.join(HERE, 'bcwhitewater', 'flow_ranges.json')
NAMES = os.path.join(HERE, 'bcwhitewater', 'bc_whitewater_all_data_with_stations.json')

STARTER_GAUGES = {'metro_vancouver_capilano', 'flowworks_lynn',
                  'environment_canada_08GA075'}
STARTER_RIVERS = ('capilano', 'lynn creek', 'mamquam')


def key(s):
    return re.sub(r'[^a-z0-9]+', ' ', str(s).lower()).strip()


def station_doc_id(station):
    m = re.search(r'(?:^|_)(\d{2}[A-Za-z]{2}\d{3})$', station or '')
    if m and (len(station) == 7 or 'environment_canada' in station.lower()):
        return f'environment_canada_{m.group(1).upper()}'
    return station or ''


def is_starter(data):
    text = f"{data.get('river', '')} {data.get('name', '')}".lower()
    return (station_doc_id(data.get('stationId')) in STARTER_GAUGES
            or any(r in text for r in STARTER_RIVERS))


def main(argv):
    apply = '--apply' in argv
    keep_edits = '--keep-edits' in argv
    root = os.path.dirname(HERE)
    cred = os.path.join(root, 'firebase-service-account.json')
    if not os.path.exists(cred):
        print(f'Put firebase-service-account.json in {root} first '
              '(Firebase console > Project settings > Service accounts > '
              'Generate new private key).')
        return 1

    with open(RANGES, encoding='utf-8') as f:
        ranges = {k: v for k, v in json.load(f).items() if not k.startswith('_')}
    with open(NAMES, encoding='utf-8') as f:
        names = {r['slug']: r['title'] for r in json.load(f)['reaches']}

    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(credentials.Certificate(cred))
    runs = {d.id: d for d in firestore.client().collection('river_runs').stream()}
    by_name = {key((d.to_dict() or {}).get('name', '')): d for d in runs.values()}

    updates = {}
    missing = []
    for slug, entry in sorted(ranges.items()):
        doc = runs.get(slug) or by_name.get(key(names.get(slug, slug)))
        if doc is None:
            missing.append(slug)
            continue
        want = {'source': 'BC Whitewater', **entry}
        have = (doc.to_dict() or {}).get('flowRanges')
        if have == want or (keep_edits and isinstance(have, dict) and have):
            continue
        updates.setdefault(doc.id, {})['flowRanges'] = want

    for doc in runs.values():
        data = doc.to_dict() or {}
        if is_starter(data) and data.get('starter') is not True:
            updates.setdefault(doc.id, {})['starter'] = True

    db = firestore.client()
    for run_id, fields in sorted(updates.items()):
        print(f'  {run_id}: {", ".join(fields)}')
        if apply:
            db.collection('river_runs').document(run_id).update(fields)
    for slug in missing:
        print(f'  ? {slug}: no run with this id or name, skipped')

    if not updates:
        print('Everything is already in the backend. Nothing to do.')
    elif apply:
        print(f'Done: updated {len(updates)} runs.')
    else:
        print(f'{len(updates)} runs would change. Run again with --apply to save.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
