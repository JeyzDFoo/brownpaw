# brownpaw API Integration

## Overview

brownpaw uses Firebase Cloud Functions (Python) as an intermediary layer to interact with external APIs. This architecture ensures security, reliability, and centralized data management while keeping the mobile app simple and focused on reading from Firebase.

## Architecture Pattern

The data flows through the following layers:

1. **brownpaw Mobile App** - Reads from Firebase only
2. **Firebase Firestore** - Central data store for all app data
3. **Cloud Functions (Python)** - Fetches and transforms external data
4. **Environment Canada API** - Source of river level data

## Cloud Functions Architecture

### Technology Stack

- **Runtime:** Python 3.11+
- **Framework:** Firebase Functions for Python
- **HTTP Client:** requests library
- **Data Models:** Custom Python classes (Station, StationLevel, DailyMean)
- **Data Validation:** Type hints with Optional types
- **Scheduling:** Firebase Scheduler (cron)

### Benefits

✅ **Security:** API credentials never exposed in client app  
✅ **Maintainability:** Single source of truth for API integration  
✅ **Rate Limiting:** Server-side throttling prevents API abuse  
✅ **Data Consistency:** Centralized data transformation logic with type-safe models  
✅ **Error Handling:** Robust retry mechanisms and logging  
✅ **Scalability:** Automatic scaling with Firebase Functions  
✅ **Offline Support:** App reads from Firebase's offline cache  
✅ **Multi-Provider Ready:** Provider-agnostic design for USGS, local sensors, etc.

## Data Models

All Cloud Functions use standardized Python data models from `scripts/models.py`:

### Provider Enum
```python
class Provider(str, Enum):
    ENVIRONMENT_CANADA = "environment_canada"
    USGS = "usgs"
    OTHER = "other"
```

### Station
Metadata for hydrometric monitoring stations.
- Document ID format: `{provider}_{station_id}`
- Fields: provider, station_id, station_name, country, latitude, longitude, active, province_or_state

### StationLevel
Real-time water level readings (5-minute intervals).
- Updated hourly via scheduled Cloud Function
- Fields: provider, station_id, level, discharge, timestamp, trend, raw_data
- Trend calculation: rising/falling/stable (5cm threshold)

### DailyMean
Historical daily averages from HYDAT database.
- Stored in subcollection: `stations/{station_id}/daily_means/{YYYY-MM-DD}`
- Fields: provider, station_id, date, level, discharge, raw_data
- Used for long-term charts and seasonal analysis

## Cloud Functions

### 1. Scheduled Function: update_river_levels

**Purpose:** Periodically fetch current river levels from Environment Canada and update Firestore.

**Schedule:** Every 60 minutes (cron: `0 * * * *`)

**Process:**
1. Retrieve list of active monitoring stations from Firestore `stations` collection
2. Bulk query Environment Canada real-time API (single call for all stations)
   - Endpoint: `https://api.weather.gc.ca/collections/hydrometric-realtime/items`
   - Limit: 10000, sorted by -DATETIME
   - Returns ~1,569 stations with most recent readings
3. For each active station in our database:
   - Parse response using `StationLevel.from_environment_canada()`
   - Calculate trend by comparing to previous reading from Firestore
   - Update `station_levels/{provider}_{station_id}` document
4. Log statistics and any errors

**Optimizations:**
- Uses bulk query (1 API call instead of 500+ individual calls)
- Filters results to only process stations we're tracking
- Batch writes to Firestore for efficiency
- Implements exponential backoff for retries

**Data Stored:**
- Provider and station ID
- Current water level (meters) and discharge (m³/s)
- Timestamp of reading
- Trend indicator (rising/falling/stable)
- Raw provider data (preserved for debugging)
- Last updated timestamp

### 2. Callable Function: add_river_station

**Purpose:** Admin-only function to add new river monitoring stations.

**Authentication:** Requires admin privileges (verified via custom claims)

**Process:**
1. Verify user has admin role
2. Validate required fields (provider, station_id, station_name, coordinates)
3. Verify station exists in provider's database (test API query)
4. Create Station object and save to Firestore `stations` collection
5. Trigger initial data fetch for `station_levels`
6. Return success confirmation with document ID

**Validation:**
- Checks provider API to confirm station exists
- Prevents adding invalid or non-existent stations
- Validates coordinate ranges (lat: -90 to 90, lon: -180 to 180)
- Ensures station_id is unique per provider

### 3. Callable Function: get_historical_data

**Purpose:** Fetch historical river level data on-demand for charts (real-time intervals).

**Parameters:**
- station_id (required)
- days (optional, default: 7, max: 30)

**Process:**
1. Validate station exists in Firestore
2. Fetch from Environment Canada real-time API
   - Endpoint: `https://api.weather.gc.ca/collections/hydrometric-realtime/items`
   - Filter by STATION_NUMBER and datetime range
   - Returns 5-minute interval data
3. Parse using `StationLevel.from_environment_canada()` for each reading
4. Calculate trends across the dataset
5. Return array of StationLevel objects (serialized to dict)

**Limitations:**
- Real-time API only provides last 30 days
- For data older than 30 days, use daily means API
- No caching (data is dynamic)

### 4. Scheduled Function: sync_daily_means

**Purpose:** Weekly sync of historical daily mean data from HYDAT database.

**Schedule:** Weekly on Sunday at 2 AM (cron: `0 2 * * 0`)

**Process:**
1. Retrieve list of active stations from Firestore
2. For each station:
   - Query `https://api.weather.gc.ca/collections/hydrometric-daily-mean/items`
   - Fetch last 365 days of daily means
   - Parse using `DailyMean.from_environment_canada_daily()`
   - Upsert to subcollection: `stations/{station_doc}/daily_means/{date}`
3. Clean up old data (optional: delete data older than 3 years)
4. Log sync statistics

**Batch Processing:**
- Process stations in batches of 10 to avoid timeouts
- Use Firestore batch writes for efficiency
- Continue on individual station failures

## Environment Canada API Reference

### Base Information### Base Information

- **Base URL:** https://api.weather.gc.ca/
- **API Type:** OGC API Features (GeoJSON)
- **Data Format:** JSON (GeoJSON FeatureCollection)
- **Authentication:** None (public API)
- **Rate Limiting:** Respectful usage (hourly polling is well within limits)
- **Documentation:** https://api.weather.gc.ca/

### Key Endpoints

#### Real-Time Data (5-minute intervals, last 30 days)

**Endpoint:** GET https://api.weather.gc.ca/collections/hydrometric-realtime/items

**Parameters:**
- `STATION_NUMBER` - Station ID (e.g., "08GA072")
- `f` - Response format ("json")
- `sortby` - Sort order ("-DATETIME" for most recent first)
- `limit` - Maximum records (10000 max)
- `datetime` - ISO 8601 date range (e.g., "2024-01-01T00:00:00Z/2024-12-31T23:59:59Z")

**Response:** GeoJSON FeatureCollection with properties:
- STATION_NUMBER, STATION_NAME, PROV_TERR_STATE_LOC
- DATETIME (UTC), DATETIME_LST (local time)
- LEVEL (meters), DISCHARGE (m³/s)
- LEVEL_SYMBOL_EN, DISCHARGE_SYMBOL_EN (data quality flags)

**Example:**
```bash
curl "https://api.weather.gc.ca/collections/hydrometric-realtime/items?STATION_NUMBER=08GA072&f=json&sortby=-DATETIME&limit=1"
```

**Bulk Query:** Fetch all stations at once (1 API call instead of 500+)
```bash
curl "https://api.weather.gc.ca/collections/hydrometric-realtime/items?f=json&sortby=-DATETIME&limit=10000"
# Returns ~1,569 unique stations with most recent readings
```

#### Daily Mean Data (HYDAT historical database)

**Endpoint:** GET https://api.weather.gc.ca/collections/hydrometric-daily-mean/items

**Parameters:**
- `STATION_NUMBER` - Station ID (e.g., "08GA072")
- `f` - Response format ("json")
- `sortby` - Sort order ("DATE" or "-DATE")
- `limit` - Maximum records (10000 max)
- `datetime` - ISO 8601 date range

**Response:** GeoJSON FeatureCollection with properties:
- IDENTIFIER (e.g., "08GA072.2024-12-31")
- STATION_NUMBER, STATION_NAME, PROV_TERR_STATE_LOC
- DATE (YYYY-MM-DD format)
- LEVEL (daily mean in meters), DISCHARGE (daily mean in m³/s)
- LEVEL_SYMBOL_EN, DISCHARGE_SYMBOL_EN

**Example:**
```bash
curl "https://api.weather.gc.ca/collections/hydrometric-daily-mean/items?STATION_NUMBER=08GA072&f=json&sortby=-DATE&limit=365&datetime=2024-01-01T00:00:00Z/2024-12-31T23:59:59Z"
# Returns 366 daily means for full year 2024
```

### Data Coverage

| Collection | Data Type | Time Range | Interval | Use Case |
|------------|-----------|------------|----------|----------|
| hydrometric-realtime | Real-time readings | Last 30 days | 5 minutes | Current conditions, recent trends |
| hydrometric-daily-mean | Historical averages | Full HYDAT archive | Daily | Long-term charts, seasonal patterns |

### Data Parameters

| Field | Description | Unit | Notes |
|-------|-------------|------|-------|
| LEVEL | Water level | m | Meters above gauge datum |
| DISCHARGE | Flow rate | m³/s | Cubic meters per second |
| DATETIME | UTC timestamp | ISO 8601 | Real-time collection only |
| DATE | Calendar date | YYYY-MM-DD | Daily mean collection only |

### Queryables

View all available query parameters:
- Real-time: https://api.weather.gc.ca/collections/hydrometric-realtime/queryables
- Daily mean: https://api.weather.gc.ca/collections/hydrometric-daily-mean/queryables

## Firestore Schema

See [firestore-schema.md](firestore-schema.md) for complete documentation.

### Collection: stations

**Document ID:** `{provider}_{station_id}` (e.g., "environment_canada_08GA072")

**Fields:**
- provider: "environment_canada" | "usgs" | "other"
- station_id: Provider's station identifier
- station_name: Human-readable name
- country: ISO country code
- latitude, longitude: Decimal degrees
- active: Boolean
- province_or_state: Province/state abbreviation
- provider_metadata: Provider-specific data (river name, popular runs, etc.)
- created_at, updated_at: Timestamps

### Collection: station_levels

**Document ID:** `{provider}_{station_id}` (e.g., "environment_canada_08GA072")

**Fields:**
- provider: Provider identifier
- station_id: Station identifier
- level: Water level in meters (standardized)
- discharge: Discharge in m³/s (standardized)
- timestamp: Reading timestamp
- trend: "rising" | "falling" | "stable"
- level_unit: Always "m"
- discharge_unit: Always "m³/s"
- last_updated: When we fetched this data
- raw_data: Original provider response (preserved)

### Collection: stations/{station_doc_id}/daily_means (Subcollection)

**Document ID:** `{YYYY-MM-DD}` (e.g., "2024-12-31")

**Fields:**
- provider: Provider identifier (inherited)
- station_id: Station identifier (inherited)
- date: YYYY-MM-DD format
- level: Daily mean water level in meters
- discharge: Daily mean discharge in m³/s
- level_unit: Always "m"
- discharge_unit: Always "m³/s"
- raw_data: Provider-specific flags and metadata

**Query Pattern:**
```javascript
db.collection('stations')
  .doc('environment_canada_08GA072')
  .collection('daily_means')
  .orderBy('date', 'desc')
  .limit(365)
  .get()
```

## Error Handling & Monitoring

### Error Logging

All errors are logged to Firestore for monitoring in the error_logs collection.

**Error Log Fields:**
- type: "river_level_update" or other error type
- station_id: Associated station (if applicable)
- error: Error message string
- timestamp: Firestore server timestamp
- severity: "warning" | "error" | "critical"

### Retry Strategy

- **Transient Errors:** Automatic retry with exponential backoff
- **Station Offline:** Mark as unavailable, skip for 1 hour
- **API Down:** Continue with cached data, alert admin

### Monitoring

Cloud Functions automatically log to Google Cloud Logging:
- Execution count and duration
- Error rates
- Memory usage
- Cold start frequency

## Deployment

### Project Structure

The Cloud Functions project is organized as follows:

**functions/** - Main directory
- main.py - Cloud Functions entry point
- requirements.txt - Python dependencies

**functions/environment_canada/** - EC API module
- api_client.py - Environment Canada API wrapper
- parser.py - Data parsing utilities

**functions/utils/** - Helper modules
- trends.py - Trend calculation logic
- validation.py - Data validation

**functions/tests/** - Test suite
- test_api_client.py
- test_trends.py

### Dependencies

Required Python packages:
- firebase-functions >= 0.4.0
- firebase-admin >= 6.0.0
- requests >= 2.31.0
- pydantic >= 2.5.0
- python-dateutil >= 2.8.0

### Deployment Commands

**Deploy all functions:**
firebase deploy --only functions

**Deploy specific function:**
firebase deploy --only functions:update_river_levels

**View logs:**
firebase functions:log

## Security Best Practices

1. **No Credentials in Code:** Use Firebase environment config for any future API keys
2. **Input Validation:** Validate all user inputs in callable functions
3. **Authentication:** Verify user auth tokens in callable functions
4. **Rate Limiting:** Implement per-user rate limits on callable functions
5. **Error Messages:** Don't expose internal details in error responses
6. **HTTPS Only:** All communication over HTTPS

## Future Enhancements

- **Webhook Support:** Real-time notifications from Environment Canada (if available)
- **Predictive Modeling:** ML-based flow predictions
- **Multi-Source Data:** Integrate USGS for US rivers
- **Alert System:** Proactive notifications for significant level changes
- **Data Analytics:** Aggregate statistics and patterns

---

*This document describes the backend API integration layer. For client-side implementation, see [architecture.md](architecture.md).*

```python
# functions/main.py
from firebase_functions import scheduler_fn
from firebase_admin import firestore, initialize_app
import requests
from datetime import datetime
from typing import Dict, List, Any
import xml.etree.ElementTree as ET

initialize_app()

@scheduler_fn.on_schedule(schedule="0 * * * *", timezone="America/Toronto")
def update_river_levels(event: scheduler_fn.ScheduledEvent) -> None:
    """
    Scheduled function to fetch river levels from Environment Canada.
    Runs every 60 minutes to keep data fresh.
    """
    db = firestore.client()
    
    # Get list of active monitoring stations
    stations = get_active_stations(db)
    
    print(f"Starting update for {len(stations)} river stations")
    
    for station in stations:
        try:
            # Fetch data from Environment Canada
            level_data = fetch_environment_canada_data(station['station_id'])
            
            if level_data:
                # Calculate trend based on historical data
                trend = calculate_trend(db, station['station_id'], level_data['level'])
                
                # Update Firestore
                db.collection('river_levels').document(station['station_id']).set({
                    'station_id': station['station_id'],
                    'river_id': station['river_id'],
                    'level': level_data['level'],
                    'flow': level_data['flow'],
                    'timestamp': firestore.SERVER_TIMESTAMP,
                    'trend': trend,
                    'unit_level': level_data.get('unit_level', 'm'),
                    'unit_flow': level_data.get('unit_flow', 'm³/s'),
                    'status': 'active',
                    'last_updated': datetime.utcnow().isoformat()
                }, merge=True)
                
                print(f"✓ Updated station {station['station_id']}")
            else:
                print(f"⚠ No data available for station {station['station_id']}")
                
        except Exception as e:
            print(f"✗ Error updating station {station['station_id']}: {str(e)}")
            # Log error but continue with other stations
            log_error(db, station['station_id'], str(e))
    
    print("River levels update completed")


def get_active_stations(db: firestore.Client) -> List[Dict[str, Any]]:
    """Retrieve all active river monitoring stations from Firestore."""
    stations_ref = db.collection('river_stations').where('active', '==', True)
    return [doc.to_dict() for doc in stations_ref.stream()]


def fetch_environment_canada_data(station_id: str) -> Dict[str, Any] | None:
    """
    Fetch real-time hydrometric data from Environment Canada API.
    
    Args:
        station_id: Environment Canada station identifier
        
    Returns:
        Dictionary with level and flow data, or None if unavailable
    """
    base_url = "https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline"
    
    params = {
        'stations[]': station_id,
        'parameters[]': '47',  # Water level
        'start_date': datetime.utcnow().strftime('%Y-%m-%d'),
        'end_date': datetime.utcnow().strftime('%Y-%m-%d')
    }
    
    try:
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        
        # Parse CSV response
        data = parse_environment_canada_csv(response.text)
        return data
        
    except requests.RequestException as e:
        print(f"API request failed for station {station_id}: {e}")
        return None


def parse_environment_canada_csv(csv_text: str) -> Dict[str, Any]:
    """Parse Environment Canada CSV response into structured data."""
    lines = csv_text.strip().split('\n')
    
    if len(lines) < 2:
        return None
    
    # Skip header, get most recent reading
    latest_reading = lines[-1].split(',')
    
    return {
        'level': float(latest_reading[2]) if latest_reading[2] else None,
        'flow': float(latest_reading[3]) if len(latest_reading) > 3 and latest_reading[3] else None,
        'unit_level': 'm',
        'unit_flow': 'm³/s'
    }


def calculate_trend(db: firestore.Client, station_id: str, current_level: float) -> str:
    """
    Calculate trend (rising, falling, stable) based on recent history.
    
    Args:
        db: Firestore client
        station_id: Station identifier
        current_level: Current water level
        
    Returns:
        Trend indicator: 'rising', 'falling', or 'stable'
    """
    try:
        # Get previous reading
        doc = db.collection('river_levels').document(station_id).get()
        
        if not doc.exists:
            return 'stable'
        
        previous_level = doc.to_dict().get('level')
        
        if previous_level is None:
            return 'stable'
        
        difference = current_level - previous_level
        threshold = 0.05  # 5cm threshold for trend detection
        
        if difference > threshold:
            return 'rising'
        elif difference < -threshold:
            return 'falling'
        else:
            return 'stable'
            
    except Exception as e:
        print(f"Error calculating trend: {e}")
        return 'stable'


def log_error(db: firestore.Client, station_id: str, error_message: str) -> None:
    """Log errors to Firestore for monitoring."""
    db.collection('error_logs').add({
        'type': 'river_level_update',
        'station_id': station_id,
        'error': error_message,
        'timestamp': firestore.SERVER_TIMESTAMP
    })
```

### 2. Callable Function: `add_river_station`

**Purpose:** Admin-only function to add new river monitoring stations.

**Authentication:** Requires admin privileges

**Implementation:**

```python
from firebase_functions import https_fn
from firebase_admin import auth

@https_fn.on_call()
def add_river_station(req: https_fn.CallableRequest) -> Dict[str, Any]:
    """
    Add a new river monitoring station to the database.
    Requires admin authentication.
    """
    # Verify admin privileges
    if not req.auth or not is_admin(req.auth.uid):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.PERMISSION_DENIED,
            message="Admin privileges required"
        )
    
    station_id = req.data.get('station_id')
    river_id = req.data.get('river_id')
    name = req.data.get('name')
    
    if not station_id or not river_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="station_id and river_id are required"
        )
    
    # Validate station exists with Environment Canada
    if not validate_station_exists(station_id):
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.NOT_FOUND,
            message=f"Station {station_id} not found in Environment Canada database"
        )
    
    # Add to Firestore
    db = firestore.client()
    station_ref = db.collection('river_stations').document(station_id)
    
    station_ref.set({
        'station_id': station_id,
        'river_id': river_id,
        'name': name or f"Station {station_id}",
        'active': True,
        'created_at': firestore.SERVER_TIMESTAMP,
        'created_by': req.auth.uid
    })
    
    return {'success': True, 'station_id': station_id}


def is_admin(uid: str) -> bool:
    """Check if user has admin role."""
    try:
        user = auth.get_user(uid)
        custom_claims = user.custom_claims or {}
        return custom_claims.get('admin', False)
    except Exception:
        return False


def validate_station_exists(station_id: str) -> bool:
    """Verify station exists in Environment Canada database."""
    url = f"https://wateroffice.ec.gc.ca/services/station_info?station_id={station_id}"
    try:
        response = requests.get(url, timeout=5)
        return response.status_code == 200
    except Exception:
        return False
```

### 3. Callable Function: `get_historical_data`

**Purpose:** Fetch historical river level data on-demand for charts.

**Implementation:**

```python
@https_fn.on_call()
def get_historical_data(req: https_fn.CallableRequest) -> Dict[str, Any]:
    """
    Fetch historical data for a specific river station.
    Caches results in Firestore for performance.
    """
    station_id = req.data.get('station_id')
    days = req.data.get('days', 7)  # Default to 7 days
    
    if not station_id:
        raise https_fn.HttpsError(
            code=https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
            message="station_id is required"
        )
    
    # Check cache first
    db = firestore.client()
    cache_key = f"{station_id}_{days}d"
    cache_ref = db.collection('historical_cache').document(cache_key)
    cache_doc = cache_ref.get()
    
    if cache_doc.exists:
        cache_data = cache_doc.to_dict()
        cache_age = (datetime.utcnow() - cache_data['cached_at']).total_seconds()
        
        # Cache valid for 1 hour
        if cache_age < 3600:
            return {'data': cache_data['data'], 'cached': True}
    
    # Fetch from Environment Canada
    historical_data = fetch_historical_from_ec(station_id, days)
    
    # Cache the result
    cache_ref.set({
        'data': historical_data,
        'cached_at': datetime.utcnow(),
        'station_id': station_id
    })
    
    return {'data': historical_data, 'cached': False}


def fetch_historical_from_ec(station_id: str, days: int) -> List[Dict[str, Any]]:
    """Fetch historical data from Environment Canada."""
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=days)
    
    params = {
        'stations[]': station_id,
        'parameters[]': '47',
        'start_date': start_date.strftime('%Y-%m-%d'),
        'end_date': end_date.strftime('%Y-%m-%d')
    }
    
    url = "https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline"
    response = requests.get(url, params=params, timeout=15)
    response.raise_for_status()
    
    # Parse CSV and return structured data
    return parse_historical_csv(response.text)


def parse_historical_csv(csv_text: str) -> List[Dict[str, Any]]:
    """Parse historical CSV data into list of readings."""
    lines = csv_text.strip().split('\n')[1:]  # Skip header
    
    readings = []
    for line in lines:
        parts = line.split(',')
        if len(parts) >= 3:
            readings.append({
                'timestamp': parts[0],
                'level': float(parts[2]) if parts[2] else None,
                'flow': float(parts[3]) if len(parts) > 3 and parts[3] else None
            })
    
    return readings
```

## Environment Canada API Reference

### Base Information

- **Base URL:** `https://wateroffice.ec.gc.ca/services/`
- **Data Format:** CSV, XML, JSON (depending on endpoint)
- **Authentication:** None (public API)
- **Rate Limiting:** Respectful usage (our 60-min polling is well within limits)

### Key Endpoints

#### Real-Time Data
```
GET https://wateroffice.ec.gc.ca/services/real_time_data/csv/inline
```

**Parameters:**
- `stations[]`: Station ID (e.g., "01AF009")
- `parameters[]`: Parameter code ("47" for water level, "46" for flow)
- `start_date`: YYYY-MM-DD format
- `end_date`: YYYY-MM-DD format

**Response:** CSV format with columns for timestamp, station, level, flow

#### Station Information
```
GET https://wateroffice.ec.gc.ca/services/station_info
```

**Parameters:**
- `station_id`: Station identifier

**Response:** JSON/XML with station metadata

### Data Parameters

| Code | Parameter | Unit |
|------|-----------|------|
| 46 | Discharge (Flow) | m³/s |
| 47 | Water Level | m |

## Firestore Schema

### Collection: `river_levels`

```javascript
{
  "station_id": "01AF009",           // Document ID (Environment Canada station)
  "river_id": "madawaska",           // Reference to river document
  "level": 2.45,                     // Water level in meters
  "flow": 125.3,                     // Flow in m³/s
  "timestamp": <SERVER_TIMESTAMP>,   // Firestore timestamp
  "trend": "rising",                 // "rising" | "falling" | "stable"
  "unit_level": "m",                 // Always meters
  "unit_flow": "m³/s",               // Always cubic meters per second
  "status": "active",                // Station status
  "last_updated": "2025-12-31T14:30:00Z"
}
```

### Collection: `river_stations`

```javascript
{
  "station_id": "01AF009",           // Document ID
  "river_id": "madawaska",
  "name": "Madawaska River at Arnprior",
  "latitude": 45.4333,
  "longitude": -76.3500,
  "active": true,
  "created_at": <SERVER_TIMESTAMP>,
  "created_by": "admin_uid"
}
```

### Collection: `historical_cache`

```javascript
{
  "cache_key": "01AF009_7d",         // Document ID: {station}_{days}
  "station_id": "01AF009",
  "data": [...],                     // Array of historical readings
  "cached_at": <TIMESTAMP>,
  "expires_at": <TIMESTAMP>
}
```

## Error Handling & Monitoring

### Error Logging

All errors are logged to Firestore for monitoring:

```javascript
// Collection: error_logs
{
  "type": "river_level_update",
  "station_id": "01AF009",
  "error": "Connection timeout",
  "timestamp": <SERVER_TIMESTAMP>,
  "severity": "warning"
}
```

### Retry Strategy

- **Transient Errors:** Automatic retry with exponential backoff
- **Station Offline:** Mark as unavailable, skip for 1 hour
- **API Down:** Continue with cached data, alert admin

### Monitoring

Cloud Functions automatically log to Google Cloud Logging:
- Execution count and duration
- Error rates
- Memory usage
- Cold start frequency

## Deployment

### Project Structure

```
functions/
├── main.py                 # Cloud Functions entry point
├── requirements.txt        # Python dependencies
├── environment_canada/
│   ├── __init__.py
│   ├── api_client.py      # EC API wrapper
│   └── parser.py          # Data parsing utilities
├── utils/
│   ├── __init__.py
│   ├── trends.py          # Trend calculation
│   └── validation.py      # Data validation
└── tests/
    ├── test_api_client.py
    └── test_trends.py
```

### Dependencies (`requirements.txt`)

```
firebase-functions>=0.4.0
firebase-admin>=6.0.0
requests>=2.31.0
pydantic>=2.5.0
python-dateutil>=2.8.0
```

### Deployment Commands

```bash
# Deploy all functions
firebase deploy --only functions

# Deploy specific function
firebase deploy --only functions:update_river_levels

# View logs
firebase functions:log
```

## Security Best Practices

1. **No Credentials in Code:** Use Firebase environment config for any future API keys
2. **Input Validation:** Validate all user inputs in callable functions
3. **Authentication:** Verify user auth tokens in callable functions
4. **Rate Limiting:** Implement per-user rate limits on callable functions
5. **Error Messages:** Don't expose internal details in error responses
6. **HTTPS Only:** All communication over HTTPS

## Future Enhancements

- **Webhook Support:** Real-time notifications from Environment Canada (if available)
- **Predictive Modeling:** ML-based flow predictions
- **Multi-Source Data:** Integrate USGS for US rivers
- **Alert System:** Proactive notifications for significant level changes
- **Data Analytics:** Aggregate statistics and patterns

---

*This document describes the backend API integration layer. For client-side implementation, see [architecture.md](architecture.md).*
