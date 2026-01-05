#!/usr/bin/env python3
"""
Fetch real-time river level data from Environment Canada API.

Usage:
    python fetch_station_levels.py <station_id>
    python fetch_station_levels.py 08GA072
"""

import requests
import sys
from typing import Optional, Dict, Any
from pathlib import Path

# Add parent directory to path to import models
sys.path.insert(0, str(Path(__file__).parent.parent))
from models import StationLevel, calculate_trend


def fetch_river_level(station_id: str) -> Optional[StationLevel]:
    """
    Fetch current river level data for a specific station.
    
    Args:
        station_id: Environment Canada station identifier (e.g., "08GA072")
        
    Returns:
        StationLevel object with level and flow data, or None if unavailable
    """
    base_url = "https://api.weather.gc.ca/collections/hydrometric-realtime/items"
    
    params = {
        'STATION_NUMBER': station_id,
        'f': 'json',
        'sortby': '-DATETIME',  # Sort by datetime descending
        'limit': 1  # Get only the most recent reading
    }
    
    try:
        print(f"Fetching data for station {station_id}...")
        response = requests.get(base_url, params=params, timeout=10)
        response.raise_for_status()
        
        # Parse JSON response and create StationLevel object
        station_level = parse_json_response(response.json(), station_id)
        
        if station_level:
            print(f"\n✓ Successfully retrieved data for station {station_id}")
            return station_level
        else:
            print(f"\n✗ No data available for station {station_id}")
            return None
            
    except requests.RequestException as e:
        print(f"\n✗ Error fetching data: {e}")
        return None


def parse_json_response(json_data: dict, station_id: str) -> Optional[StationLevel]:
    """
    Parse Environment Canada JSON response.
    
    Args:
        json_data: JSON response from API
        station_id: Station identifier for reference
        
    Returns:
        StationLevel object with parsed data or None
    """
    try:
        features = json_data.get('features', [])
        
        if not features:
            return None
        
        # Get the first (most recent) feature
        feature = features[0]
        
        # Use the from_environment_canada class method
        return StationLevel.from_environment_canada(feature)
        
    except (KeyError, IndexError, TypeError) as e:
        print(f"Error parsing data: {e}")
        return None


def display_data(station_level: StationLevel) -> None:
    """Pretty print the river level data."""
    raw_data = station_level.raw_data
    
    print("\n" + "=" * 70)
    print("RIVER LEVEL DATA")
    print("=" * 70)
    print(f"Station ID:      {station_level.station_id}")
    print(f"Station Name:    {raw_data.get('station_name', 'N/A')}")
    print(f"Province:        {raw_data.get('province', 'N/A')}")
    print(f"Timestamp:       {raw_data.get('datetime_local', 'N/A')}")
    print(f"Water Level:     {station_level.level if station_level.level else 'N/A'} {station_level.level_unit}")
    print(f"Discharge:       {station_level.discharge if station_level.discharge else 'N/A'} {station_level.discharge_unit}")
    print(f"Trend:           {station_level.trend.value}")
    if raw_data.get('coordinates'):
        coords = raw_data.get('coordinates')
        print(f"Coordinates:     {coords[1]:.5f}, {coords[0]:.5f}")
    print(f"\nFirestore Doc:   {station_level.document_id}")
    print("=" * 70 + "\n")


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: python fetch_station_levels.py <station_id>")
        print("Example: python fetch_station_levels.py 08GA072")
        sys.exit(1)
    
    station_id = sys.argv[1]
    
    # Fetch data
    data = fetch_river_level(station_id)
    
    if data:
        display_data(data)
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
