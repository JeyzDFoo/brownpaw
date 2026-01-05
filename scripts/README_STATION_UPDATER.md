# Daily Station Updater

Automated script for updating Environment Canada hydrometric station data in Firestore.

## Overview

This script runs daily to:
1. Discover all Environment Canada stations referenced in the `river_runs` collection
2. Identify new vs existing stations in the `station_data` collection
3. Fetch 5 years of historical data for new stations
4. Fetch recent data (last 3 days) for existing stations
5. Update Firestore with the latest data

## Firestore Schema

### Collection Structure

```
station_data/
├── environment_canada_{station_id}/
│   ├── metadata/
│   │   └── info                      # Station metadata document
│   └── readings/
│       ├── 2021                      # Yearly readings document
│       ├── 2022
│       ├── 2023
│       ├── 2024
│       └── 2025
```

### Metadata Document Schema

```javascript
{
  "station_id": "08HD006",
  "provider": "environment_canada",
  "station_name": "Beaver River At Kinbasket",
  "first_data_fetch": Timestamp,
  "last_updated": Timestamp,
  "is_active": true,
  "river_runs": [],
  "created_at": Timestamp
}
```

### Yearly Readings Document Schema

```javascript
{
  "year": 2024,
  "daily_readings": {
    "2024-01-01": {
      "mean_discharge": 45.6,  // m³/s
      "mean_level": 1.23        // meters
    },
    "2024-01-02": {
      "mean_discharge": 46.2,
      "mean_level": 1.25
    },
    // ... up to 365/366 entries per year
  },
  "updated_at": Timestamp
}
```

## Usage

### Run with Dry Run (No Firestore Writes)

```bash
python3 daily_station_updater.py --dry-run
```

### Run Normally (Update Firestore)

```bash
python3 daily_station_updater.py
```

### Options

```bash
# Override default 5-year lookback for new stations
python3 daily_station_updater.py --historical-days 3650  # 10 years

# Force historical data fetch for all stations (not just new ones)
python3 daily_station_updater.py --force-historical

# Set log level
python3 daily_station_updater.py --log-level DEBUG

# Combine options
python3 daily_station_updater.py --dry-run --log-level INFO
```

## Configuration

Default configuration in `daily_station_updater.py`:

```python
CONFIG = {
    'historical_days_for_new_stations': 1825,  # 5 years
    'recent_data_buffer_days': 3,              # Last 3 days for existing stations
    'batch_size': 100,
    'log_level': 'INFO',
}
```

## Scheduling for Daily Execution

### Option 1: Cron Job (Linux/macOS)

```bash
# Edit crontab
crontab -e

# Add line to run at 2 AM daily
0 2 * * * cd /path/to/brownpaw/scripts && python3 daily_station_updater.py >> /var/log/station_updater.log 2>&1
```

### Option 2: Google Cloud Scheduler + Cloud Functions

Deploy as a Cloud Function triggered by Cloud Scheduler for serverless execution.

### Option 3: systemd Timer (Linux)

Create a systemd service and timer for more robust scheduling.

## Components

### Files

- **daily_station_updater.py** - Main script orchestrating the update process
- **station_data_manager.py** - Firestore operations for station_data collection
- **environment_canada/daily_data_service.py** - API client for Environment Canada data

### Dependencies

```bash
# Install required packages
pip install firebase-admin requests
```

Or use the existing requirements:

```bash
cd environment_canada
pip install -r requirements.txt
```

## How It Works

### 1. Station Discovery

Queries all documents in the `river_runs` collection and extracts unique station IDs from:
- `stationId` field
- `gaugeStation.code` field

### 2. New vs Existing Detection

Checks the `station_data` collection to determine which stations already have data by looking for existing metadata documents.

### 3. Data Fetching

**New Stations:**
- Fetches 5 years (1,825 days) of historical daily mean data
- Creates metadata document
- Writes data organized by year

**Existing Stations:**
- Fetches only last 3 days of data
- Merges new readings into existing yearly documents
- Updates `last_updated` timestamp

### 4. Batch Writing

Uses Firestore batch writes (up to 500 operations per batch) for efficiency and cost optimization.

### 5. Error Handling

- Retries failed API calls (up to 3 attempts with exponential backoff)
- Continues processing other stations if one fails
- Comprehensive logging for monitoring

## Monitoring

The script provides detailed logging output:

```
======================================================================
SUMMARY
======================================================================
New Stations:
  Processed: 1
  Success: 1
  Failed: 0

Existing Stations:
  Processed: 5
  Success: 5
  Failed: 0

Total readings fetched: 1,456
Execution time: 12.45 seconds
======================================================================
```

## Troubleshooting

### No Data Found

If the API returns no data for a station:
- Verify the station ID is correct
- Check if the station is active on Environment Canada's website
- Some stations may have gaps in data availability

### API Timeouts

The script includes retry logic with exponential backoff. If timeouts persist:
- Check network connectivity
- Verify Environment Canada API is operational
- Consider increasing timeout in `DailyDataService`

### Firestore Permission Errors

Ensure `firebase-service-account.json` is present in the project root with appropriate permissions.

## Future Enhancements

- [ ] Support for additional data providers (USGS, etc.)
- [ ] Correlation of station data with specific river runs
- [ ] Data quality validation and anomaly detection
- [ ] Email/Slack notifications for failures
- [ ] Performance metrics dashboard
- [ ] Incremental updates based on actual last_updated time
