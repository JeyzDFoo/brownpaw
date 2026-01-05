"""
Google Cloud Functions for BrownPaw station data updates.

Entry points for two scheduled functions:
1. update_realtime_data: Runs every 3 hours, fetches 30 days of hourly data
2. update_daily_averages: Runs once daily, calculates today's average from cached data
"""

import sys
import logging
from pathlib import Path
import asyncio

# Add scripts directory to path
functions_dir = Path(__file__).parent
scripts_dir = functions_dir / 'scripts'
sys.path.insert(0, str(scripts_dir))
sys.path.insert(0, str(scripts_dir / 'environment_canada'))

# Import update modules
import realtime_updater
import daily_updater


# Setup logging for Cloud Functions
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# Cloud Functions entry points
def update_realtime_data(request):
    """
    HTTP Cloud Function for realtime data updates.
    Scheduled to run every 3 hours via Cloud Scheduler.
    """
    try:
        result = asyncio.run(realtime_updater.run_update())
        return {'status': 'success', 'result': result}, 200
    except Exception as e:
        logger.error(f"Function error: {e}", exc_info=True)
        return {'status': 'error', 'error': str(e)}, 500


def update_daily_averages(request):
    """
    HTTP Cloud Function for daily average calculations.
    Scheduled to run once daily via Cloud Scheduler.
    """
    try:
        result = daily_updater.run_update()
        return {'status': 'success', 'result': result}, 200
    except Exception as e:
        logger.error(f"Function error: {e}", exc_info=True)
        return {'status': 'error', 'error': str(e)}, 500
