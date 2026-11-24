#!/usr/bin/env python3
"""Backfill every gauge's daily history now, with no time budget.

The daily Cloud Function does the same work a few stations a day. Run
this once from the functions folder, with firebase-service-account.json
there, to fill everything at once (a few minutes):

    cd functions && python backfill.py
"""

import logging
import os
import sys
from pathlib import Path

os.environ['HYDAT_BUDGET_SECONDS'] = '1e9'
here = Path(__file__).parent
sys.path.insert(0, str(here / 'scripts'))
sys.path.insert(0, str(here / 'scripts' / 'environment_canada'))

import daily_updater  # noqa: E402

if __name__ == '__main__':
    logging.basicConfig(level=logging.INFO, format='%(message)s')
    print(daily_updater.run_update())
