#!/usr/bin/env python3
"""
Daily Station Updater - Main script for updating Environment Canada station data.

This script runs daily to:
1. Discover all Environment Canada stations from river_runs
2. Identify new vs existing stations
3. Fetch historical data (5 years) for new stations
4. Fetch recent data for existing stations
5. Update Firestore station_data collection

Usage:
    python daily_station_updater.py [--dry-run] [--historical-days N]
    
Options:
    --dry-run           Run without writing to Firestore
    --historical-days   Override default 5-year lookback for new stations
    --force-historical  Fetch historical data for all stations (not just new)
"""

import sys
import argparse
from datetime import datetime, timezone, timedelta
from typing import Dict, Set, List, Any
from pathlib import Path
import logging

# Add environment_canada directory to path
sys.path.insert(0, str(Path(__file__).parent / 'environment_canada'))
from daily_data_service import DailyDataService

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent))
from station_data_manager import StationDataManager
from models import Provider


# Configuration
CONFIG = {
    'historical_days_for_new_stations': 1825,  # 5 years
    'calculate_today_from_realtime': True,  # Calculate today's daily average from realtime hourly data
    'batch_size': 100,
    'log_level': 'INFO',
}


def setup_logging(level: str = 'INFO') -> logging.Logger:
    """Setup logging configuration."""
    logging.basicConfig(
        level=getattr(logging, level),
        format='%(asctime)s - %(levelname)s - %(message)s',
        datefmt='%Y-%m-%d %H:%M:%S'
    )
    return logging.getLogger(__name__)


def process_new_station(
    station_id: str,
    data_service: DailyDataService,
    manager: StationDataManager,
    historical_days: int,
    logger: logging.Logger,
    dry_run: bool = False
) -> Dict[str, Any]:
    """
    Process a new station by fetching historical data.
    
    Returns:
        Dict with processing stats
    """
    logger.info(f"  Processing NEW station: {station_id}")
    
    stats = {
        'station_id': station_id,
        'status': 'failed',
        'readings_fetched': 0,
        'years_written': 0,
    }
    
    try:
        # Get station info
        station_info = data_service.get_station_info(station_id)
        station_name = station_info['station_name'] if station_info else f'Station {station_id}'
        
        logger.info(f"    Fetching {historical_days} days of historical data...")
        
        # Fetch historical data
        readings = data_service.fetch_historical_data(station_id, days=historical_days)
        stats['readings_fetched'] = len(readings)
        
        if not readings:
            logger.warning(f"    ✗ No data found for {station_id}")
            return stats
        
        # Organize by year
        readings_by_year = data_service.organize_by_year(readings)
        stats['years_written'] = len(readings_by_year)
        
        logger.info(f"    ✓ Fetched {len(readings)} readings across {len(readings_by_year)} years")
        
        if not dry_run:
            # Prepare batch operations
            operations = []
            
            # Create metadata
            operations.append({
                'type': 'create_metadata',
                'provider': Provider.ENVIRONMENT_CANADA,
                'station_id': station_id,
                'station_name': station_name,
                'river_runs': [],  # Will be populated by correlating with river_runs later
            })
            
            # Write yearly readings
            for year, daily_readings in readings_by_year.items():
                operations.append({
                    'type': 'write_readings',
                    'provider': Provider.ENVIRONMENT_CANADA,
                    'station_id': station_id,
                    'year': year,
                    'daily_readings': daily_readings,
                })
            
            # Execute batch write
            manager.batch_write_station_data(operations)
            logger.info(f"    ✓ Wrote data to Firestore")
        else:
            logger.info(f"    [DRY RUN] Would write {len(readings_by_year)} year documents")
        
        stats['status'] = 'success'
        
    except Exception as e:
        logger.error(f"    ✗ Error processing {station_id}: {e}")
        stats['error'] = str(e)
    
    return stats


def process_existing_station(
    station_id: str,
    data_service: DailyDataService,
    manager: StationDataManager,
    logger: logging.Logger,
    dry_run: bool = False,
    force_historical: bool = False
) -> Dict[str, Any]:
    """
    Process an existing station by calculating today's daily average from cached realtime data.
    
    Returns:
        Dict with processing stats
    """
    logger.info(f"  Processing EXISTING station: {station_id}")
    
    stats = {
        'station_id': station_id,
        'status': 'failed',
        'daily_reading_calculated': False,
    }
    
    try:
        if force_historical:
            # Force fetch historical data
            logger.info(f"    Force fetching historical data...")
            readings = data_service.fetch_historical_data(station_id)
            stats['readings_fetched'] = len(readings)
            
            if readings:
                readings_by_year = data_service.organize_by_year(readings)
                stats['years_updated'] = len(readings_by_year)
                logger.info(f"    ✓ Fetched {len(readings)} historical readings")
                
                if not dry_run:
                    operations = []
                    for year, daily_readings in readings_by_year.items():
                        operations.append({
                            'type': 'write_readings',
                            'provider': Provider.ENVIRONMENT_CANADA,
                            'station_id': station_id,
                            'year': year,
                            'daily_readings': daily_readings,
                        })
                    operations.append({
                        'type': 'update_metadata',
                        'provider': Provider.ENVIRONMENT_CANADA,
                        'station_id': station_id,
                    })
                    manager.batch_write_station_data(operations)
                    logger.info(f"    ✓ Updated Firestore")
                else:
                    logger.info(f"    [DRY RUN] Would update {len(readings_by_year)} year documents")
        
        # Calculate today's daily average from cached realtime data in Firestore
        logger.info(f"    Calculating today's daily average from cached realtime data...")
        
        # Get cached hourly readings from station_current collection
        doc_id = f"{Provider.ENVIRONMENT_CANADA}_{station_id}"
        current_doc = manager.db.collection('station_current').document(doc_id).get()
        
        if not current_doc.exists:
            logger.warning(f"    ✗ No cached realtime data found in Firestore")
            stats['status'] = 'success'
            return stats
        
        current_data = current_doc.to_dict()
        hourly_readings_dict = current_data.get('hourly_readings', {})
        
        if not hourly_readings_dict:
            logger.warning(f"    ✗ No hourly readings in cached data")
            stats['status'] = 'success'
            return stats
        
        # Convert dict back to list format for processing
        hourly_readings = []
        for dt_str, reading in hourly_readings_dict.items():
            hourly_readings.append({
                'datetime': dt_str,
                'discharge': reading.get('discharge'),
                'level': reading.get('level'),
            })
        
        daily_readings = calculate_daily_averages_from_realtime(hourly_readings, logger)
        
        if daily_readings:
            stats['daily_reading_calculated'] = True
            # Get the most recent date
            latest_date = max(daily_readings.keys())
            logger.info(f"    ✓ Calculated daily average for {latest_date}")
            
            if not dry_run:
                # Write today's reading to Firestore
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
                logger.info(f"    ✓ Wrote today's daily average to Firestore")
            else:
                logger.info(f"    [DRY RUN] Would write today's daily average")
        else:
            logger.warning(f"    ✗ Could not calculate daily average from cached data")
        
        stats['status'] = 'success'
        
    except Exception as e:
        logger.error(f"    ✗ Error processing {station_id}: {e}")
        stats['error'] = str(e)
    
    return stats


def calculate_daily_averages_from_realtime(
    hourly_readings: List[Dict[str, Any]],
    logger: logging.Logger
) -> Dict[str, Dict[str, Any]]:
    """
    Calculate daily averages from hourly realtime readings.
    
    Args:
        hourly_readings: List of hourly readings with datetime, discharge, level
        
    Returns:
        Dict mapping date strings to reading data (compatible with organize_by_year)
    """
    from collections import defaultdict
    
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
        
        # Calculate averages for each parameter
        discharges = [r['discharge'] for r in day_readings if r.get('discharge') is not None]
        levels = [r['level'] for r in day_readings if r.get('level') is not None]
        
        daily_reading = {}
        
        if discharges:
            daily_reading['mean_discharge'] = round(sum(discharges) / len(discharges), 2)
        if levels:
            daily_reading['mean_level'] = round(sum(levels) / len(levels), 3)
            
        # Only add if we have at least one measurement
        if daily_reading:
            daily_readings[date_str] = daily_reading
    
    logger.debug(f"    Calculated {len(daily_readings)} daily averages from {len(hourly_readings)} hourly readings")
    return daily_readings


def main():
    """Main execution function."""
    parser = argparse.ArgumentParser(
        description='Update Environment Canada station data in Firestore'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Run without writing to Firestore'
    )
    parser.add_argument(
        '--historical-days',
        type=int,
        default=CONFIG['historical_days_for_new_stations'],
        help='Days of historical data to fetch for new stations (default: 1825)'
    )
    parser.add_argument(
        '--force-historical',
        action='store_true',
        help='Fetch historical data for all stations, not just new ones'
    )
    parser.add_argument(
        '--log-level',
        default=CONFIG['log_level'],
        choices=['DEBUG', 'INFO', 'WARNING', 'ERROR'],
        help='Set logging level'
    )
    parser.add_argument(
        '--limit',
        type=int,
        help='Limit number of stations to process (for testing)'
    )
    
    args = parser.parse_args()
    
    # Setup logging
    logger = setup_logging(args.log_level)
    
    logger.info("=" * 70)
    logger.info("DAILY STATION DATA UPDATER")
    logger.info("=" * 70)
    
    if args.dry_run:
        logger.info(">>> DRY RUN MODE - No data will be written <<<")
    
    start_time = datetime.now()
    
    try:
        # Initialize services
        logger.info("\n1. Initializing services...")
        manager = StationDataManager()
        data_service = DailyDataService()
        
        # Discover all stations from river_runs
        logger.info("\n2. Discovering stations from river_runs...")
        stations_by_provider = manager.get_all_river_run_stations()
        
        ec_stations = stations_by_provider.get(Provider.ENVIRONMENT_CANADA, set())
        logger.info(f"   Found {len(ec_stations)} Environment Canada stations")
        
        if not ec_stations:
            logger.warning("   No stations found. Exiting.")
            return
        
        # Identify new vs existing stations
        logger.info("\n3. Identifying new vs existing stations...")
        new_stations, existing_stations = manager.get_stations_needing_update(
            Provider.ENVIRONMENT_CANADA,
            ec_stations
        )
        
        logger.info(f"   New stations: {len(new_stations)}")
        logger.info(f"   Existing stations: {len(existing_stations)}")
        
        # Apply limit if specified
        if args.limit and args.limit > 0:
            new_stations = set(sorted(new_stations)[:args.limit])
            existing_stations = set(sorted(existing_stations)[:args.limit])
            logger.info(f"   Limiting to first {args.limit} of each for testing")
        
        # Process new stations
        new_stats = []
        if new_stations:
            logger.info(f"\n4. Processing {len(new_stations)} NEW stations...")
            for station_id in sorted(new_stations):
                stats = process_new_station(
                    station_id,
                    data_service,
                    manager,
                    args.historical_days,
                    logger,
                    dry_run=args.dry_run
                )
                new_stats.append(stats)
        
        # Process existing stations - calculate today's daily average from realtime
        existing_stats = []
        if existing_stations:
            logger.info(f"\n5. Processing {len(existing_stations)} EXISTING stations...")
            for station_id in sorted(existing_stations):
                stats = process_existing_station(
                    station_id,
                    data_service,
                    manager,
                    logger,
                    dry_run=args.dry_run,
                    force_historical=args.force_historical
                )
                existing_stats.append(stats)
        
        # Print summary
        duration = datetime.now() - start_time
        logger.info("\n" + "=" * 70)
        logger.info("SUMMARY")
        logger.info("=" * 70)
        
        new_success = sum(1 for s in new_stats if s['status'] == 'success')
        new_failed = len(new_stats) - new_success
        
        existing_success = sum(1 for s in existing_stats if s['status'] == 'success')
        existing_failed = len(existing_stats) - existing_success
        
        logger.info(f"New Stations:")
        logger.info(f"  Processed: {len(new_stats)}")
        logger.info(f"  Success: {new_success}")
        logger.info(f"  Failed: {new_failed}")
        
        logger.info(f"\nExisting Stations:")
        logger.info(f"  Processed: {len(existing_stats)}")
        logger.info(f"  Success: {existing_success}")
        logger.info(f"  Failed: {existing_failed}")
        daily_calculated = sum(1 for s in existing_stats if s.get('daily_reading_calculated'))
        logger.info(f"  Today's daily averages calculated: {daily_calculated}")
        
        total_readings = sum(s.get('readings_fetched', 0) for s in new_stats + existing_stats)
        logger.info(f"\nTotal readings processed: {total_readings}")
        logger.info(f"Execution time: {duration.total_seconds():.2f} seconds")
        
        if args.dry_run:
            logger.info("\n>>> DRY RUN COMPLETE - No data was written <<<")
        
        logger.info("=" * 70)
        
    except Exception as e:
        logger.error(f"\n✗ Fatal error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
