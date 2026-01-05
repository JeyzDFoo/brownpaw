#!/usr/bin/env python3
"""
Daily Realtime Station Updater - Updates current station conditions.

This script runs frequently (e.g., hourly) to fetch the latest real-time readings
from Environment Canada and update Firestore with current river conditions.

Unlike the historical updater which uses daily means, this uses real-time data
which is updated hourly with minimal lag.

Usage:
    python3 daily_realtime_updater.py [--dry-run] [--hours N]
"""

import sys
import argparse
from datetime import datetime, timezone
from typing import Dict, Set, List, Any
from pathlib import Path
import logging
import asyncio
from google.cloud.firestore import SERVER_TIMESTAMP

# Add environment_canada directory to path
sys.path.insert(0, str(Path(__file__).parent / 'environment_canada'))
from realtime_data_service import RealtimeDataService

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent))
from station_data_manager import StationDataManager
from models import Provider


# Configuration
CONFIG = {
    'hours_to_fetch': 720,  # Fetch last 30 days (30 * 24 = 720 hours)
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


async def update_station_realtime(
    station_id: str,
    data_service: RealtimeDataService,
    manager: StationDataManager,
    hours: int,
    logger: logging.Logger,
    dry_run: bool = False
) -> Dict[str, Any]:
    """
    Fetch and update real-time data for a station.
    
    Returns:
        Dict with update stats
    """
    stats = {
        'station_id': station_id,
        'status': 'failed',
        'readings_fetched': 0,
        'latest_reading': None,
    }
    
    try:
        # Get station status
        status = await data_service.get_station_status(station_id)
        
        if status['status'] == 'no_data':
            logger.warning(f"    ✗ No real-time data available for {station_id}")
            return stats
        
        latest = status['latest_reading']
        data_age = status['data_age_hours']
        
        logger.info(f"    Latest reading: {latest['datetime']} ({data_age:.1f}h ago)")
        logger.info(f"    Level: {latest.get('level')} m, Discharge: {latest.get('discharge')} m³/s")
        logger.info(f"    Trend: {status['trend']}, Readings in 48h: {status['readings_48h']}")
        
        stats['readings_fetched'] = status['readings_48h']
        stats['latest_reading'] = latest
        stats['data_age_hours'] = data_age
        stats['trend'] = status['trend']
        
        if not dry_run:
            # Get all recent readings
            all_readings = await data_service.fetch_latest_readings(station_id, hours=hours)
            
            # Store in Firestore: station_current collection
            doc_id = f"{Provider.ENVIRONMENT_CANADA}_{station_id}"
            current_ref = manager.db.collection('station_current').document(doc_id)
            
            # Convert readings list to dict keyed by datetime for efficient lookups
            readings_dict = {}
            for reading in all_readings:
                dt_key = reading['datetime']
                readings_dict[dt_key] = {
                    'discharge': reading.get('discharge'),
                    'level': reading.get('level'),
                }
            
            current_data = {
                'station_id': station_id,
                'provider': Provider.ENVIRONMENT_CANADA,
                'station_name': latest.get('station_name'),
                'latest_reading': {
                    'datetime': latest['datetime'],
                    'discharge': latest.get('discharge'),
                    'level': latest.get('level'),
                },
                'trend': status['trend'],
                'data_age_hours': data_age,
                'hourly_readings': readings_dict,  # All hourly readings for last N days
                'readings_count': len(readings_dict),
                'updated_at': SERVER_TIMESTAMP,
            }
            
            current_ref.set(current_data)
            logger.info(f"    ✓ Stored {len(readings_dict)} hourly readings in Firestore")
        else:
            logger.info(f"    [DRY RUN] Would store {status['readings_48h']} hourly readings")
        
        stats['status'] = 'success'
        
    except Exception as e:
        logger.error(f"    ✗ Error updating {station_id}: {e}")
        stats['error'] = str(e)
    
    return stats


async def async_main(args, logger):
    """Async main execution function."""
    parser = argparse.ArgumentParser(
        description='Update real-time station data in Firestore'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Run without writing to Firestore'
    )
    parser.add_argument(
        '--hours',
        type=int,
        default=CONFIG['hours_to_fetch'],
        help='Hours of data to fetch (default: 336 = 14 days)'
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
    logger.info("REALTIME STATION DATA UPDATER")
    logger.info("=" * 70)
    
    if args.dry_run:
        logger.info(">>> DRY RUN MODE - No data will be written <<<")
    
    start_time = datetime.now()
    
    try:
        # Initialize services
        logger.info("\n1. Initializing services...")
        manager = StationDataManager()
        
        # Discover all stations from river_runs
        logger.info("\n2. Discovering stations from river_runs...")
        stations_by_provider = manager.get_all_river_run_stations()
        
        ec_stations = stations_by_provider.get(Provider.ENVIRONMENT_CANADA, set())
        logger.info(f"   Found {len(ec_stations)} Environment Canada stations")
        
        if not ec_stations:
            logger.warning("   No stations found. Exiting.")
            return
        
        # Apply limit if specified
        stations_to_process = sorted(ec_stations)
        if args.limit:
            stations_to_process = stations_to_process[:args.limit]
            logger.info(f"   Limiting to first {len(stations_to_process)} stations for testing")
        
        # Update all stations concurrently using async
        logger.info(f"\n3. Updating {len(stations_to_process)} stations with real-time data...")
        
        async with RealtimeDataService() as data_service:
            # Create tasks for all stations
            tasks = []
            for i, station_id in enumerate(stations_to_process, 1):
                logger.info(f"\n[{i}/{len(stations_to_process)}] {station_id}")
                task = update_station_realtime(
                    station_id,
                    data_service,
                    manager,
                    args.hours,
                    logger,
                    dry_run=args.dry_run
                )
                tasks.append(task)
            
            # Run all tasks concurrently
            all_stats = await asyncio.gather(*tasks, return_exceptions=False)
        
        # Print summary
        duration = datetime.now() - start_time
        logger.info("\n" + "=" * 70)
        logger.info("SUMMARY")
        logger.info("=" * 70)
        
        success = sum(1 for s in all_stats if s.get('status') == 'success')
        failed = len(all_stats) - success
        
        logger.info(f"Stations processed: {len(all_stats)}")
        logger.info(f"  Success: {success}")
        logger.info(f"  Failed: {failed}")
        
        total_readings = sum(s.get('readings_fetched', 0) for s in all_stats)
        logger.info(f"\nTotal readings fetched: {total_readings}")
        logger.info(f"Execution time: {duration.total_seconds():.2f} seconds")
        
        if args.dry_run:
            logger.info("\n>>> DRY RUN COMPLETE - No data was written <<<")
        
        logger.info("=" * 70)
        
    except Exception as e:
        logger.error(f"\n✗ Fatal error: {e}", exc_info=True)
        sys.exit(1)


def main():
    """Main entry point - runs async main."""
    parser = argparse.ArgumentParser(
        description='Update current station conditions using real-time data from Environment Canada'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Run without writing to Firestore'
    )
    parser.add_argument(
        '--hours',
        type=int,
        default=CONFIG['hours_to_fetch'],
        help='Hours of data to fetch (default: 336 = 14 days)'
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
    logger = setup_logging(args.log_level)
    
    logger.info("=" * 70)
    logger.info("REALTIME STATION DATA UPDATER")
    logger.info("=" * 70)
    
    if args.dry_run:
        logger.info(">>> DRY RUN MODE - No data will be written <<<")
    
    # Run the async main function
    asyncio.run(async_main(args, logger))


if __name__ == '__main__':
    main()
