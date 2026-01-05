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
    'recent_data_buffer_days': 3,  # Fetch last 3 days for existing stations
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
    recent_days: int,
    logger: logging.Logger,
    dry_run: bool = False,
    force_historical: bool = False
) -> Dict[str, Any]:
    """
    Process an existing station by fetching recent data.
    
    Returns:
        Dict with processing stats
    """
    logger.info(f"  Processing EXISTING station: {station_id}")
    
    stats = {
        'station_id': station_id,
        'status': 'failed',
        'readings_fetched': 0,
        'years_updated': 0,
    }
    
    try:
        if force_historical:
            # Force fetch historical data
            logger.info(f"    Force fetching historical data...")
            readings = data_service.fetch_historical_data(station_id)
        else:
            # Fetch recent data
            logger.info(f"    Fetching last {recent_days} days...")
            readings = data_service.fetch_latest_data(station_id, days=recent_days)
        
        stats['readings_fetched'] = len(readings)
        
        if not readings:
            logger.warning(f"    ✗ No new data found for {station_id}")
            return stats
        
        # Organize by year
        readings_by_year = data_service.organize_by_year(readings)
        stats['years_updated'] = len(readings_by_year)
        
        logger.info(f"    ✓ Fetched {len(readings)} readings")
        
        if not dry_run:
            # Prepare batch operations
            operations = []
            
            # Write/merge yearly readings
            for year, daily_readings in readings_by_year.items():
                operations.append({
                    'type': 'write_readings',
                    'provider': Provider.ENVIRONMENT_CANADA,
                    'station_id': station_id,
                    'year': year,
                    'daily_readings': daily_readings,
                })
            
            # Update metadata timestamp
            operations.append({
                'type': 'update_metadata',
                'provider': Provider.ENVIRONMENT_CANADA,
                'station_id': station_id,
            })
            
            # Execute batch write
            manager.batch_write_station_data(operations)
            logger.info(f"    ✓ Updated Firestore")
        else:
            logger.info(f"    [DRY RUN] Would update {len(readings_by_year)} year documents")
        
        stats['status'] = 'success'
        
    except Exception as e:
        logger.error(f"    ✗ Error processing {station_id}: {e}")
        stats['error'] = str(e)
    
    return stats


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
        
        # Process existing stations
        existing_stats = []
        if existing_stations:
            logger.info(f"\n5. Processing {len(existing_stations)} EXISTING stations...")
            for station_id in sorted(existing_stations):
                stats = process_existing_station(
                    station_id,
                    data_service,
                    manager,
                    CONFIG['recent_data_buffer_days'],
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
        
        total_readings = sum(s.get('readings_fetched', 0) for s in new_stats + existing_stats)
        logger.info(f"\nTotal readings fetched: {total_readings}")
        logger.info(f"Execution time: {duration.total_seconds():.2f} seconds")
        
        if args.dry_run:
            logger.info("\n>>> DRY RUN COMPLETE - No data was written <<<")
        
        logger.info("=" * 70)
        
    except Exception as e:
        logger.error(f"\n✗ Fatal error: {e}", exc_info=True)
        sys.exit(1)


if __name__ == '__main__':
    main()
