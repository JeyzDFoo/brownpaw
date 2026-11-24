#!/usr/bin/env python3
"""Store every run's gauge in one form, and check history has moved.

Runs name their gauge in `stationId`, written over the years as `08MH001`,
`Provider.ENVIRONMENT_CANADA_08MH001` or `environment_canada_08MH001`.
The app and Cloud Functions now use only `environment_canada_08MH001`
(code in capitals); Metro Vancouver and Flowworks ids are already in that
form. This rewrites the others.

It also checks that the daily Cloud Function has copied each station's
history from the old `station_data/Provider.ENVIRONMENT_CANADA_{code}`
document (the app no longer reads it), and lists any that haven't.

    python scripts/normalize_station_ids.py           # dry run + check
    python scripts/normalize_station_ids.py --apply

Needs firebase-service-account.json in the working directory, like the
other scripts here. Safe to run again.
"""

import re
import sys

import firebase_admin
from firebase_admin import credentials, firestore

EC_CODE = re.compile(r'(?:^|_)(\d{2}[A-Z]{2}\d{3})$', re.IGNORECASE)


def canonical(station_id: str) -> str:
    """`environment_canada_08MH001` for any Environment Canada form; other
    providers' ids unchanged."""
    match = EC_CODE.search(station_id or '')
    if match and (len(station_id) == 7
                  or 'environment_canada' in station_id.lower()):
        return f"environment_canada_{match.group(1).upper()}"
    return station_id


def main(argv):
    apply = '--apply' in argv
    try:
        firebase_admin.get_app()
    except ValueError:
        firebase_admin.initialize_app(
            credentials.Certificate('firebase-service-account.json'))
    db = firestore.client()

    changes, stations = [], set()
    for doc in db.collection('river_runs').stream():
        old = (doc.to_dict() or {}).get('stationId')
        if not isinstance(old, str) or not old:
            continue
        new = canonical(old)
        stations.add(new)
        if new != old:
            changes.append((doc, old, new))

    print(f"{len(changes)} of the runs with a gauge need a new id form")
    for doc, old, new in changes[:30]:
        print(f"  {doc.id}: {old} -> {new}")

    not_moved = []
    for station in sorted(s for s in stations
                          if s.startswith('environment_canada_')):
        code = station.rsplit('_', 1)[1]
        meta = db.collection('station_data').document(station).get()
        moved = meta.exists and (meta.to_dict() or {}).get('migrated_legacy')
        legacy = db.collection('station_data').document(
            f"Provider.ENVIRONMENT_CANADA_{code}").get()
        if legacy.exists and not moved:
            not_moved.append(station)
    if not_moved:
        print(f"\n{len(not_moved)} stations still have history only under the "
              "old id. Deploy the functions and let the daily update run once "
              "before releasing the app:")
        for s in not_moved:
            print(f"  {s}")
    else:
        print("\nAll station history is under the new ids.")

    if not apply:
        print('\nDry run. Re-run with --apply to rewrite the run ids.')
        return 0
    batch, count = db.batch(), 0
    for doc, _, new in changes:
        batch.update(doc.reference, {'stationId': new})
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
    batch.commit()
    print(f"Updated {count} runs.")
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
