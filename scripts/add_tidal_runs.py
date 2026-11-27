#!/usr/bin/env python3
"""Add the tidal play spots in scripts/tidal/tidal_runs.json to Firestore.

    python3 scripts/add_tidal_runs.py            # dry run
    python3 scripts/add_tidal_runs.py --apply

Each entry becomes `river_runs/{key}` as a curated public BC run. Safe to
run again: only fields that differ from what's stored are written, and
fields edited only in the console are left alone. Pass --keep-edits to
skip runs that already exist.

The gauge itself (station_current/tidal_sechelt_rapids) is written by the
Cloud Functions (functions/tidal.py) on their next hourly run.

Needs firebase-service-account.json in the repo folder.
"""

import json
import os
import sys

import firebase_admin
from firebase_admin import credentials, firestore

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.join(HERE, 'tidal', 'tidal_runs.json')


def run_doc(entry: dict) -> dict:
    doc = {k: v for k, v in entry.items() if k != 'pinNote'}
    doc.update({
        'province': 'BC',
        'verified': True,
        'visibility': 'public',
        'hasValidStation': bool(entry.get('stationId')),
    })
    doc.setdefault('flowUnit', 'kt')
    return doc


def changes(want: dict, have: dict) -> dict:
    return {k: v for k, v in want.items() if have.get(k) != v}


def main(argv):
    apply = '--apply' in argv
    keep_edits = '--keep-edits' in argv
    root = os.path.dirname(HERE)
    cred = os.path.join(root, 'firebase-service-account.json')
    if not os.path.exists(cred):
        print(f'Put firebase-service-account.json in {root} first.')
        return 1
    with open(DATA, encoding='utf-8') as f:
        runs = {k: v for k, v in json.load(f).items() if not k.startswith('_')}

    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(credentials.Certificate(cred))
    col = firestore.client().collection('river_runs')

    todo = 0
    for run_id, entry in sorted(runs.items()):
        snap = col.document(run_id).get()
        if snap.exists and keep_edits:
            continue
        want = run_doc(entry)
        diff = changes(want, snap.to_dict() or {}) if snap.exists else want
        if not diff:
            continue
        todo += 1
        print(f"  {'update' if snap.exists else 'add'} {run_id}: "
              f"{', '.join(sorted(diff))}")
        if apply:
            fields = dict(diff)
            fields['updatedAt'] = firestore.SERVER_TIMESTAMP
            if not snap.exists:
                fields['createdAt'] = firestore.SERVER_TIMESTAMP
            col.document(run_id).set(fields, merge=True)

    if not todo:
        print('Everything is already in the backend. Nothing to do.')
    elif apply:
        print(f'Done: wrote {todo} runs.')
    else:
        print(f'{todo} runs would change. Run again with --apply to save.')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
