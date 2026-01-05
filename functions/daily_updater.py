"""
Daily Average Updater for Cloud Functions.
Calculates daily averages from cached realtime data once per day.
"""

import logging
from datetime import datetime
from collections import defaultdict

from scripts.station_data_manager import StationDataManager
from scripts.models import Provider
from scripts.environment_canada.daily_data_service import DailyDataService


logger = logging.getLogger(__name__)


def calculate_daily_averages(hourly_readings: list) -> dict:
    """
    Calculate daily averages from hourly readings.
    
    Args:
        hourly_readings: List of dicts with datetime, discharge, level
        
    Returns:
        Dict mapping date strings to daily averages
    """
    # Group readings by date
    readings_by_date = defaultdict(list)
    for reading in hourly_readings:
        dt = datetime.fromisoformat(reading['datetime'].replace('Z', '+00:00'))
        date_str = dt.strftime('%Y-%m-%d')
        readings_by_date[date_str].append(reading)
    
    # Calculate daily averages
    daily_readings = {}
    for date_str in sorted(readings_by_date.keys()):
        day_readings = readings_by_date[date_str]
        
        discharges = [r['discharge'] for r in day_readings if r.get('discharge') is not None]
        levels = [r['level'] for r in day_readings if r.get('level') is not None]
        
        daily_reading = {}
        if discharges:
            daily_reading['mean_discharge'] = round(sum(discharges) / len(discharges), 2)
        if levels:
            daily_reading['mean_level'] = round(sum(levels) / len(levels), 3)
        
        if daily_reading:
            daily_readings[date_str] = daily_reading
    
    return daily_readings


def process_station(station_id: str, data_service: DailyDataService, manager: StationDataManager):
    """Process one station's daily average from cached data."""
    try:
        logger.info(f"  Processing station {station_id}...")
        
        # Get cached hourly readings from station_current collection
        doc_id = f"{Provider.ENVIRONMENT_CANADA}_{station_id}"
        current_doc = manager.db.collection('station_current').document(doc_id).get()
        
        if not current_doc.exists:
            logger.warning(f"    No cached data for {station_id}")
            return {'station_id': station_id, 'status': 'no_cache'}
        
        current_data = current_doc.to_dict()
        hourly_readings_dict = current_data.get('hourly_readings', {})
        
        if not hourly_readings_dict:
            logger.warning(f"    No hourly readings for {station_id}")
            return {'station_id': station_id, 'status': 'no_readings'}
        
        # Convert dict back to list for processing
        hourly_readings = []
        for dt_str, reading in hourly_readings_dict.items():
            hourly_readings.append({
                'datetime': dt_str,
                'discharge': reading.get('discharge'),
                'level': reading.get('level'),
            })
        
        # Calculate daily averages
        daily_readings = calculate_daily_averages(hourly_readings)
        
        if not daily_readings:
            logger.warning(f"    Could not calculate averages for {station_id}")
            return {'station_id': station_id, 'status': 'no_averages'}
        
        # Get the most recent date (today)
        latest_date = max(daily_readings.keys())
        
        # Organize by year and write to Firestore
        readings_by_year = data_service.organize_by_year(daily_readings)
        operations = []
        for year, yearly_readings in readings_by_year.items():
            operations.append({
                'type': 'write_readings',
                'provider': Provider.ENVIRONMENT_CANADA,
                'station_id': station_id,
                'year': year,
                'daily_readings': yearly_readings,
            })
        manager.batch_write_station_data(operations)
        
        logger.info(f"    ✓ Wrote daily average for {latest_date}")
        return {'station_id': station_id, 'status': 'success', 'date': latest_date}
        
    except Exception as e:
        logger.error(f"    ✗ Error processing {station_id}: {e}")
        return {'station_id': station_id, 'status': 'error', 'error': str(e)}


def run_update():
    """Main function for daily average updates."""
    logger.info("=" * 70)
    logger.info("DAILY AVERAGE UPDATE (Cloud Function)")
    logger.info("=" * 70)
    
    start_time = datetime.now()
    
    # Initialize services
    logger.info("Initializing services...")
    manager = StationDataManager()
    data_service = DailyDataService()
    
    # Get all stations
    logger.info("Discovering stations from river_runs...")
    stations_by_provider = manager.get_all_river_run_stations()
    ec_stations = stations_by_provider.get(Provider.ENVIRONMENT_CANADA, set())
    
    logger.info(f"Found {len(ec_stations)} Environment Canada stations")
    
    # Get existing stations (skip new ones - they need historical data)
    logger.info("Identifying existing stations...")
    existing_stations = set()
    for station_id in ec_stations:
        doc_id = f"{Provider.ENVIRONMENT_CANADA}_{station_id}"
        doc = manager.db.collection('station_data').document(doc_id).get()
        if doc.exists:
            existing_stations.add(station_id)
    
    logger.info(f"Processing {len(existing_stations)} existing stations...")
    
    # Process stations
    results = [
        process_station(station_id, data_service, manager)
        for station_id in sorted(existing_stations)
    ]
    
    # Summary
    success = sum(1 for r in results if r['status'] == 'success')
    failed = len(results) - success
    
    duration = datetime.now() - start_time
    
    logger.info("=" * 70)
    logger.info("SUMMARY")
    logger.info(f"Stations processed: {len(results)}")
    logger.info(f"Success: {success}")
    logger.info(f"Failed: {failed}")
    logger.info(f"Execution time: {duration.total_seconds():.2f} seconds")
    logger.info("=" * 70)
    
    return {
        'success': success,
        'failed': failed,
        'duration_seconds': duration.total_seconds()
    }
