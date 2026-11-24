#!/usr/bin/env python3
"""Point a run at an Environment Canada gauge.

The Gauges tab and the Cloud Functions only know a station once a run
uses it, so a run without a gauge (Lynn Creek) has no gauge to search.

    python scripts/set_run_gauge.py "Lynn Creek" 08GA012          # dry run
    python scripts/set_run_gauge.py "Lynn Creek" 08GA012 --apply

The first argument is a run document id or (part of) a run name. Needs
firebase-service-account.json in the working directory, like the other
scripts here. The station shows up after the next realtime update
(every 3 hours), with daily history from the next daily run.
"""

import re
import sys

import firebase_admin
from firebase_admin import credentials, firestore


def main(argv):
    args = [a for a in argv if not a.startswith('--')]
    if len(args) != 2:
        print(__doc__)
        return 2
    query, code = args[0], args[1].upper()
    if not re.fullmatch(r'\d{2}[A-Z]{2}\d{3}', code):
        print(f"'{code}' doesn't look like an Environment Canada station code")
        return 2
    apply = '--apply' in argv

    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(
            credentials.Certificate('firebase-service-account.json'))
    db = firestore.client()

    runs = db.collection('river_runs')
    doc = runs.document(query).get()
    matches = [doc] if doc.exists else [
        d for d in runs.stream()
        if query.lower() in str((d.to_dict() or {}).get('name', '')).lower()
    ]
    if not matches:
        print(f"No run matches '{query}'")
        return 1

    for d in matches:
        data = d.to_dict() or {}
        print(f"{d.id}: {data.get('name')} - stationId "
              f"{data.get('stationId')!r} -> {code!r}")
        if apply:
            gauge = dict(data.get('gaugeStation') or {})
            gauge.update({'code': code, 'provider': 'environment_canada'})
            d.reference.update({'stationId': code, 'gaugeStation': gauge})
    print('Updated.' if apply else 'Dry run. Add --apply to save.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
