"""
Realtime Data Updater for Cloud Functions.
Fetches 30 days of hourly data from Environment Canada every 3 hours.
"""

import logging
from datetime import datetime, timezone
import asyncio

import flow_alerts
import flowworks
import metro_vancouver
import transalta
from scripts.station_data_manager import StationDataManager
from scripts.models import Provider
from scripts.environment_canada.realtime_data_service import RealtimeDataService


logger = logging.getLogger(__name__)


async def process_station(station_id: str, service: RealtimeDataService, manager: StationDataManager):
    """Process one station's realtime data."""
    try:
        logger.info(f"  Processing station {station_id}...")
        logger.info(f"    Step 1: Fetching 720 hours of data...")
        
        # Fetch 30 days (720 hours) of hourly data
        readings = await service.fetch_latest_readings(station_id, hours=720)
        
        logger.info(f"    Step 2: Got {len(readings)} readings")
        
        if not readings:
            logger.warning(f"    No readings fetched for {station_id}")
            return {'station_id': station_id, 'status': 'no_data', 'readings': 0}
        
        logger.info(f"    Step 3: Fetching station status...")
        
        # Get station status (latest + trend)
        status = await service.get_station_status(station_id)
        
        logger.info(f"    Step 4: Got status, latest={status.get('latest_reading', {}).get('datetime') if status else None}")
        
        if not status:
            logger.warning(f"    No status available for {station_id}")
            return {'station_id': station_id, 'status': 'no_status', 'readings': len(readings)}
        
        logger.info(f"    Step 5: Converting {len(readings)} readings to CSV...")
        
        # Convert readings to CSV string to avoid Firestore index limits
        csv_lines = ['datetime,discharge,level']
        for r in readings:
            discharge = r.get('discharge', '')
            level = r.get('level', '')
            csv_lines.append(f"{r['datetime']},{discharge},{level}")
        readings_csv = '\n'.join(csv_lines)
        
        csv_size = len(readings_csv.encode('utf-8'))
        logger.info(f"    Step 6: CSV created, size={csv_size:,} bytes ({csv_size/1024:.1f} KB)")
        
        # Store in Firestore
        logger.info(f"    Step 7: Writing to Firestore...")
        manager.write_current_station_data(
            provider=Provider.ENVIRONMENT_CANADA.value,
            station_id=station_id,
            latest_reading=status['latest_reading'],
            trend=status['trend'],
            hourly_readings_csv=readings_csv,
            updated_at=datetime.now()
        )
        
        logger.info(f"    ✓ Stored {len(readings)} readings for {station_id}")
        return {
            'station_id': station_id,
            'status': 'success',
            'readings': len(readings),
            'discharge': (status.get('latest_reading') or {}).get('discharge'),
            'level': (status.get('latest_reading') or {}).get('level'),
            'reading_time': (status.get('latest_reading') or {}).get('datetime'),
            'trend': status.get('trend'),
            'station_name': next(
                (r.get('station_name') for r in readings if r.get('station_name')),
                None,
            ),
        }
        
    except Exception as e:
        # Log full error with traceback for debugging
        import traceback
        error_details = traceback.format_exc()
        logger.error(f"    ✗ Error processing {station_id}:")
        logger.error(f"    Exception type: {type(e).__name__}")
        logger.error(f"    Exception message: {str(e)}")
        logger.error(f"    Full traceback:")
        for line in error_details.split('\n'):
            if line.strip():
                logger.error(f"      {line}")
        return {'station_id': station_id, 'status': 'error', 'error': str(e)}


def write_station_names(db, results):
    """Writes a small summary per station to stations/{provider}_{code}:
    its official name and latest flow. The app reads this one collection
    to name gauges and colour map pins without downloading every
    station's hourly readings."""
    provider = Provider.ENVIRONMENT_CANADA.value
    batch = db.batch()
    count = 0
    for r in results:
        if r.get('status') != 'success':
            continue
        summary = {
            'stationNumber': r['station_id'],
            'provider': provider,
            'flow': r.get('discharge'),
            # Some runs are read on the stick (metres), e.g. the Cheakamus.
            'level': r.get('level'),
            'trend': r.get('trend'),
            'readingTime': r.get('reading_time'),
        }
        if r.get('station_name'):
            summary['name'] = r['station_name']
        ref = db.collection('stations').document(f"{provider}_{r['station_id']}")
        batch.set(ref, summary, merge=True)
        count += 1
        if count % 400 == 0:
            batch.commit()
            batch = db.batch()
    batch.commit()
    logger.info(f"Station summaries written: {count}")


def degraded(success: int, failed: int) -> bool:
    """Worth an alert: nothing updated, or more than a quarter failed."""
    total = success + failed
    return total > 0 and (success == 0 or failed / total > 0.25)


def write_health(db, success: int, failed_ids: list, metro_ok: list,
                 now: datetime = None):
    """`app_config/gauge_health`: when the gauges last updated and what
    failed, for the app and for a quick look in the console."""
    now = now or datetime.now(timezone.utc)
    db.collection('app_config').document('gauge_health').set({
        'lastRunAt': now,
        'environmentCanadaOk': success,
        'environmentCanadaFailed': failed_ids,
        'metroVancouverOk': metro_ok,
        'degraded': degraded(success, len(failed_ids)),
    })


async def run_update():
    """Main async function for realtime updates."""
    logger.info("=" * 70)
    logger.info("REALTIME DATA UPDATE (Cloud Function) - 30 days CSV format")
    logger.info("=" * 70)
    
    start_time = datetime.now()
    
    # Initialize services
    logger.info("Initializing services...")
    manager = StationDataManager()
    
    # Get all stations
    logger.info("Discovering stations from river_runs...")
    stations_by_provider = manager.get_all_river_run_stations()
    ec_stations = stations_by_provider.get(Provider.ENVIRONMENT_CANADA, set())
    
    logger.info(f"Found {len(ec_stations)} Environment Canada stations")
    
    # Process stations concurrently
    logger.info("Fetching realtime data concurrently...")
    async with RealtimeDataService() as service:
        tasks = [
            process_station(station_id, service, manager)
            for station_id in ec_stations
        ]
        results = await asyncio.gather(*tasks)
    
    # Keep each station's official name and latest flow in
    # stations/{doc id}, so the app can title gauges and colour map pins.
    try:
        write_station_names(manager.db, results)
    except Exception as e:
        logger.error(f"Station names failed: {e}", exc_info=True)

    # Metro Vancouver's Capilano and Seymour gauges.
    try:
        metro_flows = metro_vancouver.update_realtime(manager.db)
    except Exception as e:
        logger.error(f"Metro Vancouver failed: {e}", exc_info=True)
        metro_flows = {}

    # Lynn Creek, from the Flowworks feed the club page publishes.
    try:
        lynn_flows = flowworks.update_realtime(manager.db)
    except Exception as e:
        logger.error(f"Flowworks failed: {e}", exc_info=True)
        lynn_flows = {}

    # TransAlta's Kananaskis dam release schedules.
    try:
        release_flows = transalta.update_realtime(manager.db)
    except Exception as e:
        logger.error(f"TransAlta failed: {e}", exc_info=True)
        release_flows = {}

    # Tell paddlers whose runs came into range.
    flows = {
        f"{Provider.ENVIRONMENT_CANADA.value}_{r['station_id']}": r['discharge']
        for r in results
        if r['status'] == 'success' and r.get('discharge') is not None
    }
    flows.update(metro_flows)
    flows.update(lynn_flows)
    flows.update(release_flows)
    try:
        alerts = flow_alerts.check_alerts(manager.db, flows)
    except Exception as e:
        logger.error(f"Flow alerts failed: {e}", exc_info=True)
        alerts = {'error': str(e)}

    # Summary
    success = sum(1 for r in results if r['status'] == 'success')
    failed = len(results) - success
    failed_ids = sorted(r['station_id'] for r in results if r['status'] != 'success')

    try:
        write_health(manager.db, success, failed_ids, sorted(metro_flows))
    except Exception as e:
        logger.error(f"Health record failed: {e}", exc_info=True)
    if degraded(success, failed):
        # A log-based alert in Cloud Monitoring matches this text
        # (docs/gauge-monitoring.md).
        logger.error(
            f"GAUGE_UPDATE_DEGRADED: {failed} of {len(results)} Environment "
            f"Canada stations failed: {', '.join(failed_ids[:20])}")
    total_readings = sum(r.get('readings', 0) for r in results)
    
    duration = datetime.now() - start_time
    
    logger.info("=" * 70)
    logger.info("SUMMARY")
    logger.info(f"Stations processed: {len(results)}")
    logger.info(f"Success: {success}")
    logger.info(f"Failed: {failed}")
    logger.info(f"Total readings fetched: {total_readings}")
    logger.info(f"Execution time: {duration.total_seconds():.2f} seconds")
    logger.info("=" * 70)
    
    return {
        'degraded': degraded(success, failed),
        'success': success,
        'failed': failed,
        'total_readings': total_readings,
        'duration_seconds': duration.total_seconds(),
        'alerts': alerts,
    }
