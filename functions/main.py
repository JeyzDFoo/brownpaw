"""
Google Cloud Functions for BrownPaw station data updates.

Entry points:
- scheduled_realtime_update: hourly; 30 days of hourly readings per gauge,
  flow alerts, gauge health.
- scheduled_daily_update: daily; daily means and history.
- update_realtime_data / update_daily_averages: the same jobs over HTTP, for
  running one by hand.
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
from firebase_functions import https_fn, scheduler_fn
from firebase_functions.options import MemoryOption


# Setup logging for Cloud Functions
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


# Cloud Functions entry points
@https_fn.on_request(
    region="us-central1",
    memory=MemoryOption.GB_1,
    timeout_sec=540,
    max_instances=34,
    concurrency=1,
    cpu="gcf_gen1",
)
def update_realtime_data(request):
    """
    HTTP Cloud Function for realtime data updates.
    Scheduled to run every 3 hours via Cloud Scheduler.
    """
    try:
        result = asyncio.run(realtime_updater.run_update())
        # 500 when nothing updated, so Cloud Scheduler records a failed run.
        code = 500 if result.get('success', 0) == 0 and result.get('failed') else 200
        return {'status': 'success' if code == 200 else 'degraded',
                'result': result}, code
    except Exception as e:
        logger.error(f"Function error: {e}", exc_info=True)
        return {'status': 'error', 'error': str(e)}, 500


@https_fn.on_request(
    region="us-central1",
    memory=MemoryOption.MB_256,
    timeout_sec=300,
    max_instances=100,
    concurrency=1,
    cpu="gcf_gen1",
)
def update_daily_averages(request):
    """
    HTTP Cloud Function for daily average calculations.
    Scheduled to run once daily via Cloud Scheduler.
    """
    logger.info("=" * 70)
    logger.info("update_daily_averages function called")
    logger.info("=" * 70)
    
    try:
        logger.info("Calling daily_updater.run_update()")
        result = daily_updater.run_update()
        logger.info(f"daily_updater.run_update() completed: {result}")
        return {'status': 'success', 'result': result}, 200
    except Exception as e:
        logger.error(f"Function error: {e}", exc_info=True)
        return {'status': 'error', 'error': str(e)}, 500


# Scheduled versions. `firebase deploy --only functions` creates and keeps
# their Cloud Scheduler jobs itself, so a redeploy can't leave a job
# pointing at an old URL (which stopped the gauges on 2026-11-24). The HTTP
# functions above stay for running an update by hand.
PACIFIC = scheduler_fn.Timezone("America/Vancouver")


@scheduler_fn.on_schedule(
    schedule="5 * * * *",  # hourly, just after Environment Canada's update
    timezone=PACIFIC,
    region="us-central1",
    memory=MemoryOption.GB_1,
    timeout_sec=540,
    retry_count=1,
)
def scheduled_realtime_update(event: scheduler_fn.ScheduledEvent) -> None:
    result = asyncio.run(realtime_updater.run_update())
    logger.info(f"Scheduled realtime update: {result}")
    if result.get('success', 0) == 0 and result.get('failed'):
        # Raising marks the run failed in the logs and lets it retry once.
        raise RuntimeError(f"GAUGE_UPDATE_DEGRADED: nothing updated: {result}")


@scheduler_fn.on_schedule(
    schedule="30 2 * * *",  # 2:30 AM Pacific, after the day is complete
    timezone=PACIFIC,
    region="us-central1",
    memory=MemoryOption.MB_512,
    timeout_sec=540,
    retry_count=1,
)
def scheduled_daily_update(event: scheduler_fn.ScheduledEvent) -> None:
    result = daily_updater.run_update()
    logger.info(f"Scheduled daily update: {result}")
