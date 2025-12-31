# Firestore Data Schema

This document defines the Firestore database schema for brownpaw's river level data.

## Collections

### 1. `stations`

Station metadata for hydrometric monitoring stations across different providers.

**Document ID Format:** `{provider}_{station_id}`  
Example: `environment_canada_08GA072`

**Fields:**
```typescript
{
  provider: string,              // "environment_canada", "usgs", "other"
  station_id: string,            // Provider's station identifier
  station_name: string,          // Human-readable name
  country: string,               // ISO country code (e.g., "CA", "US")
  latitude: number,              // Decimal degrees
  longitude: number,             // Decimal degrees
  active: boolean,               // Whether station is currently active
  province_or_state: string?,    // Province/state abbreviation
  river_id: string?,             // Reference to river document (future)
  provider_metadata: object,     // Provider-specific data
  created_at: timestamp?,
  updated_at: timestamp?
}
```

**Example:**
```json
{
  "provider": "environment_canada",
  "station_id": "08GA072",
  "station_name": "CHEAKAMUS RIVER ABOVE MILLAR CREEK",
  "country": "CA",
  "latitude": 50.07991,
  "longitude": -123.03562,
  "active": true,
  "province_or_state": "BC",
  "river_id": null,
  "provider_metadata": {
    "river": "Cheakamus River",
    "popular_runs": ["Cheakamus Canyon"]
  },
  "created_at": "2025-12-31T12:00:00Z",
  "updated_at": "2025-12-31T12:00:00Z"
}
```

**Indexes:**
- `provider` (for filtering by data source)
- `province_or_state` (for geographic filtering)
- Composite: `country + province_or_state` (for regional queries)

---

### 2. `station_levels`

Current real-time water level readings for stations. Updated hourly via Cloud Functions.

**Document ID Format:** `{provider}_{station_id}`  
Example: `environment_canada_08GA072`

**Fields:**
```typescript
{
  provider: string,              // "environment_canada", "usgs", "other"
  station_id: string,            // Provider's station identifier
  level: number?,                // Water level in meters
  discharge: number?,            // Discharge in m³/s
  timestamp: timestamp,          // When reading was taken
  trend: string,                 // "rising", "falling", "stable"
  level_unit: string,            // Always "m" (standardized)
  discharge_unit: string,        // Always "m³/s" (standardized)
  last_updated: timestamp,       // When we last fetched this data
  raw_data: object              // Original provider data (preserved)
}
```

**Example:**
```json
{
  "provider": "environment_canada",
  "station_id": "08GA072",
  "level": 1.854,
  "discharge": 6.8,
  "timestamp": "2025-12-31T12:05:00-08:00",
  "trend": "stable",
  "level_unit": "m",
  "discharge_unit": "m³/s",
  "last_updated": "2025-12-31T20:00:00Z",
  "raw_data": {
    "station_name": "CHEAKAMUS RIVER ABOVE MILLAR CREEK",
    "province": "BC",
    "datetime_local": "2025-12-31T12:05:00-08:00",
    "level_symbol": null,
    "discharge_symbol": null,
    "coordinates": [-123.03562, 50.07991]
  }
}
```

**Indexes:**
- `provider` (for filtering by data source)
- `last_updated` (for finding stale data)
- `trend` (for finding rising/falling rivers)

**TTL:** Consider setting TTL of 7 days if not actively monitored

---

### 3. `stations/{station_doc_id}/daily_means` (Subcollection)

Historical daily mean data for long-term analysis. Updated less frequently (weekly/monthly).

**Document ID Format:** `{YYYY-MM-DD}`  
Example: `2024-12-31`

**Path:** `stations/environment_canada_08GA072/daily_means/2024-12-31`

**Fields:**
```typescript
{
  provider: string,              // Inherited from parent but included for queries
  station_id: string,            // Inherited from parent
  date: string,                  // YYYY-MM-DD format
  level: number?,                // Daily mean water level in meters
  discharge: number?,            // Daily mean discharge in m³/s
  level_unit: string,            // Always "m"
  discharge_unit: string,        // Always "m³/s"
  raw_data: object              // Provider-specific symbols, flags, etc.
}
```

**Example:**
```json
{
  "provider": "environment_canada",
  "station_id": "08GA072",
  "date": "2024-12-31",
  "level": 1.937,
  "discharge": 8.39,
  "level_unit": "m",
  "discharge_unit": "m³/s",
  "raw_data": {
    "station_name": "CHEAKAMUS RIVER ABOVE MILLAR CREEK",
    "province": "BC",
    "level_symbol": null,
    "discharge_symbol": null,
    "identifier": "08GA072.2024-12-31",
    "coordinates": [-123.03562, 50.07991]
  }
}
```

**Indexes:**
- Composite: `date DESC` (for time-series queries)

**Notes:**
- Stored as subcollection to keep historical data organized per station
- Query pattern: `stations/{station_doc_id}/daily_means?orderBy=date&limit=365`
- Useful for charting, trend analysis, and seasonal patterns

---

## Data Flow

### Real-time Updates (Hourly)
1. Cloud Function `update_river_levels` triggered by Cloud Scheduler (cron: `0 * * * *`)
2. Fetches latest data from Environment Canada real-time API
3. Updates `station_levels` collection with current readings
4. Calculates trend by comparing to previous reading
5. Stores raw provider data in `raw_data` field

### Historical Data (On-demand or Weekly)
1. Cloud Function `sync_historical_data` (manual trigger or weekly cron)
2. Fetches daily means from HYDAT database
3. Populates `daily_means` subcollection for each station
4. Used for historical charts and analysis in app

### Adding New Stations (Admin only)
1. Cloud Function `add_river_station` (callable, authenticated)
2. Creates document in `stations` collection
3. Triggers initial data fetch for `station_levels`
4. Optionally backfills historical data

---

## Multi-Provider Design

The schema is designed to support multiple data providers:

**Currently Supported:**
- Environment Canada (primary)

**Future Providers:**
- USGS (United States Geological Survey)
- Local sensors / custom stations
- Other national hydrometric services

**Key Design Principles:**
1. All units standardized (meters, m³/s)
2. Provider-specific data preserved in `raw_data`
3. Document IDs include provider prefix
4. Provider field indexed for filtering
5. Models handle provider-specific parsing

---

## Security Rules (TODO)

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Public read access to station data
    match /stations/{stationId} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.token.admin == true;
      
      // Daily means subcollection
      match /daily_means/{date} {
        allow read: if true;
        allow write: if request.auth != null && request.auth.token.admin == true;
      }
    }
    
    // Public read access to current levels
    match /station_levels/{stationId} {
      allow read: if true;
      allow write: if false; // Only Cloud Functions can write
    }
  }
}
```

---

## Query Examples

### Get all active BC stations
```javascript
db.collection('stations')
  .where('country', '==', 'CA')
  .where('province_or_state', '==', 'BC')
  .where('active', '==', true)
  .get()
```

### Get current level for a station
```javascript
db.collection('station_levels')
  .doc('environment_canada_08GA072')
  .get()
```

### Get last 30 days of daily means
```javascript
db.collection('stations')
  .doc('environment_canada_08GA072')
  .collection('daily_means')
  .orderBy('date', 'desc')
  .limit(30)
  .get()
```

### Find all rising rivers
```javascript
db.collection('station_levels')
  .where('trend', '==', 'rising')
  .where('provider', '==', 'environment_canada')
  .get()
```

---

## Storage Estimates

**Per Station:**
- `stations` document: ~1 KB
- `station_levels` document: ~2 KB
- `daily_means` document: ~1 KB each

**For 500 Stations (BC + AB):**
- Stations: 500 KB
- Current levels: 1 MB
- Daily means (1 year): 500 stations × 365 days × 1 KB = ~180 MB/year

**Firestore Free Tier:** 1 GB storage, 50K reads/day, 20K writes/day
- Well within limits for initial deployment
