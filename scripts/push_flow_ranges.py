#!/usr/bin/env python3
"""Write each run's low / medium / high flows to Firestore.

The app reads `river_runs/{id}.flowRanges` first, so once this has run you
can change a run's flows in the Firebase console (or by editing
scripts/bcwhitewater/flow_ranges.json and running this again) and every
copy of the app picks it up straight away, no release needed. The copy
bundled in the app is only a fallback for runs without one.

    python scripts/push_flow_ranges.py                 # dry run, all runs
    python scripts/push_flow_ranges.py --apply
    python scripts/push_flow_ranges.py lynn-creek --apply   # just one

flowRanges fields: unit ("cms" or "m"), low, medium, high, max (each is
where that level starts; any may be left out), station (the gauge the
numbers are read on), gauge (words, when it's not an online gauge), note,
source. Needs firebase-service-account.json in the working directory.
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


def key(s):
    return re.sub(r'[^a-z0-9]+', ' ', s.lower()).strip()


def main(argv):
    apply = '--apply' in argv
    only = {a for a in argv if not a.startswith('--')}
    with open(RANGES, encoding='utf-8') as f:
        ranges = {k: v for k, v in json.load(f).items() if not k.startswith('_')}
    with open(NAMES, encoding='utf-8') as f:
        names = {r['slug']: r['title'] for r in json.load(f)['reaches']}
    if only:
        ranges = {k: v for k, v in ranges.items() if k in only}

    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(
            credentials.Certificate('firebase-service-account.json'))
    runs = firestore.client().collection('river_runs')
    by_name = None

    written = missing = 0
    for slug, entry in sorted(ranges.items()):
        data = {'source': 'BC Whitewater', **entry}
        doc = runs.document(slug).get()
        if not doc.exists:
            if by_name is None:
                by_name = {key(str((d.to_dict() or {}).get('name', ''))): d
                           for d in runs.stream()}
            doc = by_name.get(key(names.get(slug, slug)))
        if doc is None or not doc.exists:
            print(f'  ? {slug}: no run with this id or name')
            missing += 1
            continue
        print(f'  {doc.id}: {data}')
        if apply:
            doc.reference.update({'flowRanges': data})
        written += 1
    verb = 'Wrote' if apply else 'Would write'
    print(f'{verb} {written} runs; {missing} not found.'
          + ('' if apply else ' Add --apply to save.'))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
