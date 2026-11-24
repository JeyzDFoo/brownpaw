#!/usr/bin/env python3
"""Backfill every gauge's daily history now, with no time budget.

The daily Cloud Function does the same work a few stations a day. Run
this once from the functions folder to fill everything at once (a few
minutes):

    cd functions && python3 backfill.py

Credentials, first found wins: functions/firebase-service-account.json,
then the repo root's firebase-service-account.json, then your gcloud
application default credentials. Either way it writes to the app's
project (brownclaw) and says which project and how many runs it read.
"""

import logging
import os
import sys
from pathlib import Path

os.environ['HYDAT_BUDGET_SECONDS'] = '1e9'
here = Path(__file__).parent
sys.path.insert(0, str(here / 'scripts'))
sys.path.insert(0, str(here / 'scripts' / 'environment_canada'))

import firebase_admin  # noqa: E402
from firebase_admin import credentials, firestore  # noqa: E402

PROJECT = os.environ.get('BROWNPAW_PROJECT', 'brownclaw')


def init_firebase() -> str:
    """Initializes the app against PROJECT; returns where creds came from."""
    for path in (here / 'firebase-service-account.json',
                 here.parent / 'firebase-service-account.json'):
        if path.exists():
            firebase_admin.initialize_app(
                credentials.Certificate(str(path)), {'projectId': PROJECT})
            return str(path)
    firebase_admin.initialize_app(options={'projectId': PROJECT})
    return 'gcloud application default credentials'


if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO, format='%(message)s')
    source = init_firebase()
    import daily_updater  # noqa: E402  (after init, so it reuses this app)
    from scripts.station_data_manager import StationDataManager  # noqa: E402

    manager = StationDataManager()
    runs = sum(1 for _ in manager.db.collection('river_runs').select(['stationId']).stream())
    stations = manager.get_all_river_run_stations()
    ec = next(iter(stations.values()), set()) if stations else set()
    print(f"Project {PROJECT} via {source}: {runs} runs, "
          f"{len(ec)} Environment Canada stations")
    if not ec:
        print("No Environment Canada stations found, so nothing to backfill. "
              "If runs is 0, these credentials point at the wrong project or "
              "can't read river_runs.")
        sys.exit(1)
    print(daily_updater.run_update(stations=ec))
