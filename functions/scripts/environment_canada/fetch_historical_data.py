#!/usr/bin/env python3
"""
Fetch historical river level data from Environment Canada API.

Usage:
    python fetch_historical_data.py <station_id> <days>
    python fetch_historical_data.py 08GA072 7
"""

import requests
import sys
from datetime import datetime, timedelta
from typing import List, Dict, Any
from pathlib import Path

# Add parent directory to path to import models
sys.path.insert(0, str(Path(__file__).parent.parent))
from models import StationLevel, calculate_trend


def fetch_historical_data(station_id: str, days: int = 7) -> List[StationLevel]:
    """
    Fetch historical river level data for a specific station.
    
    Args:
        station_id: Environment Canada station identifier
        days: Number of days of historical data to fetch (default: 7)
        
    Returns:
        List of StationLevel objects with historical readings
    """
    base_url = "https://api.weather.gc.ca/collections/hydrometric-realtime/items"
    
    # Calculate date range
    end_date = datetime.utcnow()
    start_date = end_date - timedelta(days=days)
    
    params = {
        'STATION_NUMBER': station_id,
        'f': 'json',
        'sortby': '-DATETIME',
        'limit': 10000,  # Get maximum readings
        'datetime': f"{start_date.strftime('%Y-%m-%dT%H:%M:%SZ')}/{end_date.strftime('%Y-%m-%dT%H:%M:%SZ')}"
    }
    
    try:
        print(f"Fetching {days} days of historical data for station {station_id}...")
        response = requests.get(base_url, params=params, timeout=15)
        response.raise_for_status()
        
        # Parse JSON response
        readings = parse_historical_json(response.json())
        
        print(f"\n✓ Successfully retrieved {len(readings)} readings")
        return readings
            
    except requests.RequestException as e:
        print(f"\n✗ Error fetching data: {e}")
        return []


def parse_historical_json(json_data: dict) -> List[StationLevel]:
    """
    Parse historical JSON data into list of StationLevel objects.
    
    Args:
        json_data: JSON response from API
        
    Returns:
        List of StationLevel objects
    """
    features = json_data.get('features', [])
    
    if not features:
        return []
    
    readings = []
    for feature in features:
        try:
            station_level = StationLevel.from_environment_canada(feature)
            readings.append(station_level)
        except (KeyError, TypeError, ValueError) as e:
            print(f"Warning: Skipping invalid reading: {e}")
            continue
    
    # Sort by timestamp (oldest first)
    readings.sort(key=lambda x: x.timestamp)
    
    # Calculate trends
    for i in range(1, len(readings)):
        if readings[i-1].level is not None and readings[i].level is not None:
            readings[i].trend = calculate_trend(readings[i-1].level, readings[i].level)
    
    return readings


def display_summary(readings: List[StationLevel]) -> None:
    """Display summary statistics of historical data."""
    if not readings:
        print("\nNo data to display")
        return
    
    levels = [r.level for r in readings if r.level is not None]
    flows = [r.discharge for r in readings if r.discharge is not None]
    
    print("\n" + "=" * 60)
    print("HISTORICAL DATA SUMMARY")
    print("=" * 60)
    print(f"Total Readings:     {len(readings)}")
    print(f"Date Range:         {readings[0].timestamp} to {readings[-1].timestamp}")
    
    if levels:
        print(f"\nWater Level (m):")
        print(f"  Current:          {levels[-1]:.2f}")
        print(f"  Minimum:          {min(levels):.2f}")
        print(f"  Maximum:          {max(levels):.2f}")
        print(f"  Average:          {sum(levels)/len(levels):.2f}")
    
    if flows:
        print(f"\nFlow Rate (m³/s):")
        print(f"  Current:          {flows[-1]:.2f}")
        print(f"  Minimum:          {min(flows):.2f}")
        print(f"  Maximum:          {max(flows):.2f}")
        print(f"  Average:          {sum(flows)/len(flows):.2f}")
    
    print("=" * 60 + "\n")


def display_recent_readings(readings: List[StationLevel], count: int = 10) -> None:
    """Display the most recent readings."""
    if not readings:
        return
    
    recent = readings[-count:] if len(readings) > count else readings
    
    print(f"\nMost Recent {len(recent)} Readings:")
    print("-" * 80)
    print(f"{'Timestamp':<20} {'Level (m)':<12} {'Flow (m³/s)':<12} {'Trend':<10}")
    print("-" * 80)
    
    for reading in recent:
        timestamp = str(reading.timestamp)[:19] if reading.timestamp else 'N/A'
        level = f"{reading.level:.2f}" if reading.level is not None else 'N/A'
        flow = f"{reading.discharge:.2f}" if reading.discharge is not None else 'N/A'
        trend = reading.trend.value
        print(f"{timestamp:<20} {level:<12} {flow:<12} {trend:<10}")
    
    print("-" * 80 + "\n")


def export_to_csv(readings: List[StationLevel], station_id: str) -> None:
    """Export readings to a CSV file."""
    if not readings:
        return
    
    filename = f"historical_data_{station_id}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.csv"
    
    try:
        with open(filename, 'w') as f:
            # Write header
            f.write("timestamp,station_id,level_m,discharge_m3s,trend\n")
            
            # Write data
            for reading in readings:
                f.write(f"{reading.timestamp},{reading.station_id},")
                f.write(f"{reading.level if reading.level is not None else ''},")
                f.write(f"{reading.discharge if reading.discharge is not None else ''},")
                f.write(f"{reading.trend.value}\n")
        
        print(f"✓ Data exported to {filename}")
    except IOError as e:
        print(f"✗ Error exporting to CSV: {e}")


def main():
    """Main entry point."""
    if len(sys.argv) < 2:
        print("Usage: python fetch_historical_data.py <station_id> [days]")
        print("Example: python fetch_historical_data.py 01AF009 7")
        sys.exit(1)
    
    station_id = sys.argv[1]
    days = int(sys.argv[2]) if len(sys.argv) > 2 else 7
    
    # Fetch historical data
    readings = fetch_historical_data(station_id, days)
    
    if readings:
        display_summary(readings)
        display_recent_readings(readings, count=10)
        
        # Ask if user wants to export
        response = input("Export to CSV? (y/n): ").lower()
        if response == 'y':
            export_to_csv(readings, station_id)
        
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
