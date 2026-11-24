#!/usr/bin/env python3
"""Mark every curated run `visibility: 'public'`.

The security rules let paddlers read only runs marked public plus their
own private runs, so curated runs need the field before the new
firestore.rules is deployed. Runs a paddler added (verified false or
visibility 'private') are left alone.

    python scripts/backfill_run_visibility.py            # dry run
    python scripts/backfill_run_visibility.py --apply

Needs firebase-service-account.json in the working directory, like the
other scripts here. Safe to run again.
"""

import sys

import firebase_admin
from firebase_admin import credentials, firestore


def needs_public(run: dict) -> bool:
    """Curated runs without the field. Older records have neither
    `verified` nor `visibility`; those are curated too."""
    if run.get('visibility') is not None:
        return False
    return run.get('verified', True) is not False


def main(argv):
    apply = '--apply' in argv
    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(
            credentials.Certificate('firebase-service-account.json'))
    db = firestore.client()

    todo = [d for d in db.collection('river_runs').stream()
            if needs_public(d.to_dict() or {})]
    print(f"{len(todo)} curated runs need visibility 'public'")
    if not apply:
        for d in todo[:20]:
            print(f"  {d.id}")
        print('Dry run. Re-run with --apply to write.')
        return 0

    batch, count = db.batch(), 0
    for d in todo:
        batch.update(d.reference, {'visibility': 'public'})
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
    batch.commit()
    print(f"Updated {count} runs.")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
