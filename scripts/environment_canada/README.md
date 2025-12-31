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

### 1. fetch_river_levels.py

Fetch current river level data for a specific station.

**Usage:**
```bash
python fetch_river_levels.py <station_id>
```

**Example:**
```bash
python fetch_river_levels.py 01AF009
```

**Output:**
- Station ID
- Current timestamp
- Water level (meters)
- Flow rate (m³/s)

### 2. fetch_historical_data.py

Fetch historical river level data with summary statistics.

**Usage:**
```bash
python fetch_historical_data.py <station_id> [days]
```

**Examples:**
```bash
# Fetch 7 days of data (default)
python fetch_historical_data.py 01AF009

# Fetch 30 days of data
python fetch_historical_data.py 01AF009 30
```

**Features:**
- Summary statistics (min, max, average)
- Recent readings display
- CSV export option

### 3. list_stations.py

Browse available hydrometric stations for whitewater rivers.

**Usage:**
```bash
# List all stations
python list_stations.py

# Filter by province
python list_stations.py province Ontario

# Get station details
python list_stations.py details 01AF009
```

## Popular Stations

| Station ID | River | Province | Popular Runs |
|------------|-------|----------|--------------|
| 01AF009 | Madawaska River | Ontario | Palmer Rapids, Mountain Chute |
| 02KB001 | Kicking Horse River | British Columbia | Lower Canyon |
| 05BJ010 | Bow River | Alberta | Canmore Run |
| 08HB002 | Thompson River | British Columbia | Frog Rapid Section |
| 08NM116 | Chilliwack River | British Columbia | Upper Chilliwack |
| 02DD008 | Rouge River | Quebec | Seven Sisters |
| 02OJ007 | Jacques-Cartier River | Quebec | Canyon Section |

## API Reference

**Base URL:** https://wateroffice.ec.gc.ca/services/

**Endpoints Used:**
- Real-time data: `/real_time_data/csv/inline`

**Parameters:**
- `stations[]`: Station ID
- `parameters[]`: 47 (water level), 46 (flow)
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
