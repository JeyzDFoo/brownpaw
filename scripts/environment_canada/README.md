# Environment Canada API Scripts

Python scripts for querying Environment Canada's hydrometric data API.

## Requirements

```bash
pip install requests
```

Or install from requirements file:

```bash
pip install -r requirements.txt
```

## Scripts

### 1. fetch_station_levels.py

Fetch current real-time river level data for a specific station (last 30 days of 5-minute intervals).

**Usage:**
```bash
python fetch_station_levels.py <station_id>
```

**Example:**
```bash
python fetch_station_levels.py 08GA072
```

**Output:**
- Station ID and name
- Current timestamp
- Water level (meters)
- Discharge (m³/s)
- Trend (stable/rising/falling)
- Firestore document ID

### 2. fetch_historical_data.py

Fetch real-time historical data (5-minute intervals) for the past N days.

**Usage:**
```bash
python fetch_historical_data.py <station_id> [days]
```

**Examples:**
```bash
# Fetch 7 days of data (default)
python fetch_historical_data.py 08GA072

# Fetch 3 days of data
python fetch_historical_data.py 08GA072 3
```

**Features:**
- Summary statistics (min, max, average)
- Recent readings with trend indicators
- CSV export option
- Uses StationLevel model

### 3. fetch_daily_means.py

Fetch daily mean historical data from HYDAT database (daily averages for long-term analysis).

**Usage:**
```bash
python fetch_daily_means.py <station_id> <start_date> <end_date>
```

**Examples:**
```bash
# Fetch full year of daily averages
python fetch_daily_means.py 08GA072 2024-01-01 2024-12-31

# Fetch specific month
python fetch_daily_means.py 08GA072 2024-06-01 2024-06-30
```

**Features:**
- Daily mean water levels and discharge
- Monthly average summaries
- Summary statistics (min, max, average)
- Recent days display
- CSV export option
- Uses DailyMean model

### 4. list_stations.py

Browse available hydrometric stations for whitewater rivers.

**Usage:**
```bash
# List all stations
python list_stations.py

# Filter by province
python list_stations.py province "British Columbia"

# Get station details
python list_stations.py details 08HB002
```

## Data Models

All scripts use type-safe data models from `../models.py`:

- **Station**: Station metadata (location, name, provider)
- **StationLevel**: Real-time water level readings (5-min intervals)
- **DailyMean**: Daily average readings from HYDAT database
- **Provider**: Multi-provider support (Environment Canada, USGS, etc.)
- **Trend**: Water level trend calculation (rising/falling/stable)

## Popular Stations

| Station ID | River | Province | Popular Runs |
|------------|-------|----------|--------------|
| 01AF009 | Madawaska River | Ontario | Palmer Rapids, Mountain Chute |
| 02KB001 | Kicking Horse River | British Columbia | Lower Canyon |
| 05BJ010 | Bow River | Alberta | Canmore Run |
| 08HB002 | Thompson River | British Columbia | Frog Rapid Section |
| 08NM116 | Chilliwack River | British Columbia | Upper Chilliwack |
| 08GA072 | Cheakamus River | British Columbia | Cheakamus Canyon |
| 02DD008 | Rouge River | Quebec | Seven Sisters |
| 02OJ007 | Jacques-Cartier River | Quebec | Canyon Section |

## API Reference

**Base URL:** https://api.weather.gc.ca/

**Endpoints Used:**
- Real-time data (5-min intervals, last 30 days): `/collections/hydrometric-realtime/items`
- Daily mean data (HYDAT historical): `/collections/hydrometric-daily-mean/items`

**Common Parameters:**
- `STATION_NUMBER`: Station ID (e.g., "08GA072")
- `f`: Format (json)
- `sortby`: Sort order (+DATE or -DATETIME)
- `limit`: Maximum records (10000)
- `datetime`: Date range filter (ISO 8601 format)

**Data Format:** OGC API Features (GeoJSON)
- `start_date`: YYYY-MM-DD
- `end_date`: YYYY-MM-DD

**Data Format:** CSV

## Notes

- All measurements are in metric units (meters, m³/s)
- Data is updated hourly by Environment Canada
- Scripts include 10-15 second timeouts for API requests
- Historical data availability varies by station

## Finding More Stations

Visit the official Environment Canada site to find more stations:
https://wateroffice.ec.gc.ca

You can search by:
- River name
- Station ID
- Geographic location
- Province

## Error Handling

All scripts include error handling for:
- Network timeouts
- Invalid station IDs
- Missing data
- API unavailability

## Future Enhancements

- Interactive station map
- Automated alerts for level changes
- Flow prediction based on historical patterns
- Integration with Firebase for cloud storage
