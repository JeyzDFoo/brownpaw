"""
Daily Average Updater for Cloud Functions.
Calculates daily averages from cached realtime data once per day.
"""

import logging
from datetime import datetime, timedelta
from collections import defaultdict

from scripts.station_data_manager import StationDataManager
from scripts.models import Provider
from scripts.environment_canada.daily_data_service import DailyDataService


logger = logging.getLogger(__name__)


def calculate_daily_average_for_yesterday(hourly_readings: list) -> dict:
    """
    Calculate daily average from yesterday's hourly readings only.
    
    Args:
        hourly_readings: List of dicts with datetime, discharge, level
        
    Returns:
        Dict mapping yesterday's date string to daily average
    """
    # Get yesterday's date
    yesterday = datetime.now() - timedelta(days=1)
    yesterday_date_str = yesterday.strftime('%Y-%m-%d')
    
    # Filter readings to only yesterday's data
    yesterday_readings = []
    for reading in hourly_readings:
        dt = datetime.fromisoformat(reading['datetime'].replace('Z', '+00:00'))
        date_str = dt.strftime('%Y-%m-%d')
        if date_str == yesterday_date_str:
            yesterday_readings.append(reading)
    
    # Calculate averages for yesterday only
    if not yesterday_readings:
        return {}
    
    discharges = [r['discharge'] for r in yesterday_readings if r.get('discharge') is not None]
    levels = [r['level'] for r in yesterday_readings if r.get('level') is not None]
    
    daily_reading = {}
    if discharges:
        daily_reading['mean_discharge'] = round(sum(discharges) / len(discharges), 2)
    if levels:
        daily_reading['mean_level'] = round(sum(levels) / len(levels), 3)
    
    if daily_reading:
        return {yesterday_date_str: daily_reading}
    
    return {}


def process_new_station(station_id: str, data_service: DailyDataService, manager: StationDataManager):
    """Process a new station by fetching historical data."""
    try:
        logger.info(f"  Processing NEW station {station_id} (fetching historical data)...")
        
        # Fetch 5 years of historical data
        daily_readings = data_service.fetch_historical_data(station_id, days=1825)
        
        if not daily_readings:
            logger.warning(f"    No historical data available for {station_id}")
            return {'station_id': station_id, 'status': 'no_historical_data'}
        
        # Organize by year and write to Firestore
        readings_by_year = data_service.organize_by_year(daily_readings)
        operations = []
        for year, yearly_readings in readings_by_year.items():
            operations.append({
                'type': 'write_readings',
                'provider': Provider.ENVIRONMENT_CANADA.value,
                'station_id': station_id,
                'year': year,
                'daily_readings': yearly_readings,
            })
        manager.batch_write_station_data(operations)
        
        logger.info(f"    ✓ Wrote {len(daily_readings)} days of historical data")
        return {'station_id': station_id, 'status': 'success', 'days': len(daily_readings)}
        
    except Exception as e:
        logger.error(f"    ✗ Error processing new station {station_id}: {e}")
        return {'station_id': station_id, 'status': 'error', 'error': str(e)}


def process_existing_station(station_id: str, data_service: DailyDataService, manager: StationDataManager):
    """Process an existing station's daily average from cached data."""
    try:
        logger.info(f"  Processing station {station_id}...")
        
        # Get cached hourly readings from station_current collection
        doc_id = f"{Provider.ENVIRONMENT_CANADA.value}_{station_id}"
        current_doc = manager.db.collection('station_current').document(doc_id).get()
        
        if not current_doc.exists:
            logger.warning(f"    No cached data for {station_id}")
            return {'station_id': station_id, 'status': 'no_cache'}
        
        current_data = current_doc.to_dict()
        readings_csv = current_data.get('hourly_readings_csv', '')
        
        if not readings_csv:
            logger.warning(f"    No hourly readings for {station_id}")
            return {'station_id': station_id, 'status': 'no_readings'}
        
        # Parse CSV to array
        hourly_readings = []
        for line in readings_csv.split('\n')[1:]:  # Skip header
            if not line.strip():
                continue
            parts = line.split(',')
            if len(parts) >= 3:
                reading = {'datetime': parts[0]}
                if parts[1]:  # discharge
                    reading['discharge'] = float(parts[1])
                if parts[2]:  # level
                    reading['level'] = float(parts[2])
                hourly_readings.append(reading)
        
        if not hourly_readings:
            logger.warning(f"    No valid readings in CSV for {station_id}")
            return {'station_id': station_id, 'status': 'no_readings'}
        
        # Calculate daily average for yesterday only
        daily_readings = calculate_daily_average_for_yesterday(hourly_readings)
        
        if not daily_readings:
            logger.warning(f"    No readings for yesterday for {station_id}")
            return {'station_id': station_id, 'status': 'no_yesterday_data'}
        
        # Get yesterday's date (only one date in the dict)
        latest_date = list(daily_readings.keys())[0]
        
        # Organize by year and write to Firestore
        readings_by_year = data_service.organize_by_year(daily_readings)
        operations = []
        for year, yearly_readings in readings_by_year.items():
            operations.append({
                'type': 'write_readings',
                'provider': Provider.ENVIRONMENT_CANADA.value,
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
    
    # Separate new and existing stations
    logger.info("Identifying new vs existing stations...")
    new_stations = set()
    existing_stations = set()
    for station_id in ec_stations:
        doc_id = f"{Provider.ENVIRONMENT_CANADA}_{station_id}"
        doc = manager.db.collection('station_data').document(doc_id).get()
        if doc.exists:
            existing_stations.add(station_id)
        else:
            new_stations.add(station_id)
    
    logger.info(f"New stations: {len(new_stations)}")
    logger.info(f"Existing stations: {len(existing_stations)}")
    
    # Process new stations with historical data fetch
    results = []
    if new_stations:
        logger.info(f"Processing {len(new_stations)} new stations with historical data...")
        for station_id in sorted(new_stations):
            results.append(process_new_station(station_id, data_service, manager))
    
    # Process existing stations with yesterday's cached data
    if existing_stations:
        logger.info(f"Processing {len(existing_stations)} existing stations with yesterday's data...")
        for station_id in sorted(existing_stations):
            results.append(process_existing_station(station_id, data_service, manager))
    
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
