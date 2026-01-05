"""
Realtime Data Updater for Cloud Functions.
Fetches 30 days of hourly data from Environment Canada every 3 hours.
"""

import logging
from datetime import datetime
import asyncio

from scripts.station_data_manager import StationDataManager
from scripts.models import Provider
from scripts.environment_canada.realtime_data_service import RealtimeDataService


logger = logging.getLogger(__name__)


async def process_station(station_id: str, service: RealtimeDataService, manager: StationDataManager):
    """Process one station's realtime data."""
    try:
        logger.info(f"  Processing station {station_id}...")
        
        # Fetch 30 days (720 hours) of hourly data
        readings = await service.fetch_latest_readings(station_id, hours=720)
        
        if not readings:
            logger.warning(f"    No readings fetched for {station_id}")
            return {'station_id': station_id, 'status': 'no_data', 'readings': 0}
        
        # Get station status (latest + trend)
        status = await service.get_station_status(station_id, hours=24)
        
        if not status:
            logger.warning(f"    No status available for {station_id}")
            return {'station_id': station_id, 'status': 'no_status', 'readings': len(readings)}
        
        # Convert readings list to dict keyed by datetime for Firestore
        readings_dict = {r['datetime']: r for r in readings}
        
        # Store in Firestore
        manager.write_current_station_data(
            provider=Provider.ENVIRONMENT_CANADA,
            station_id=station_id,
            latest_reading=status['latest_reading'],
            trend=status['trend'],
            hourly_readings=readings_dict,
            updated_at=datetime.now()
        )
        
        logger.info(f"    ✓ Stored {len(readings)} readings for {station_id}")
        return {'station_id': station_id, 'status': 'success', 'readings': len(readings)}
        
    except Exception as e:
        logger.error(f"    ✗ Error processing {station_id}: {e}")
        return {'station_id': station_id, 'status': 'error', 'error': str(e)}


async def run_update():
    """Main async function for realtime updates."""
    logger.info("=" * 70)
    logger.info("REALTIME DATA UPDATE (Cloud Function)")
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
    
    # Summary
    success = sum(1 for r in results if r['status'] == 'success')
    failed = len(results) - success
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
        'success': success,
        'failed': failed,
        'total_readings': total_readings,
        'duration_seconds': duration.total_seconds()
    }
