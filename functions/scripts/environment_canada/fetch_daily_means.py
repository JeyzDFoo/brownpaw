#!/usr/bin/env python3
"""
Fetch daily mean historical data from Environment Canada HYDAT database.

This fetches daily averages for water levels and discharge, suitable for
long-term historical analysis and charting.

Usage:
    python fetch_daily_means.py <station_id> <start_date> <end_date>
    python fetch_daily_means.py 08GA072 2024-01-01 2024-12-31
"""

import requests
import sys
from datetime import datetime
from typing import List, Dict, Any
from pathlib import Path

# Add parent directory to path to import models
sys.path.insert(0, str(Path(__file__).parent.parent))
from models import DailyMean


def fetch_daily_means(station_id: str, start_date: str, end_date: str) -> List[DailyMean]:
    """
    Fetch daily mean water level data for a specific station.
    
    Args:
        station_id: Environment Canada station identifier
        start_date: Start date in YYYY-MM-DD format
        end_date: End date in YYYY-MM-DD format
        
    Returns:
        List of DailyMean objects with daily average readings
    """
    base_url = "https://api.weather.gc.ca/collections/hydrometric-daily-mean/items"
    
    params = {
        'STATION_NUMBER': station_id,
        'f': 'json',
        'sortby': 'DATE',  # Sort chronologically
        'limit': 10000,
        'datetime': f"{start_date}T00:00:00Z/{end_date}T23:59:59Z"
    }
    
    try:
        print(f"Fetching daily means for station {station_id}...")
        print(f"Date range: {start_date} to {end_date}")
        response = requests.get(base_url, params=params, timeout=15)
        response.raise_for_status()
        
        # Parse JSON response
        daily_means = parse_daily_mean_json(response.json())
        
        print(f"\n✓ Successfully retrieved {len(daily_means)} daily readings")
        return daily_means
            
    except requests.RequestException as e:
        print(f"\n✗ Error fetching data: {e}")
        return []


def parse_daily_mean_json(json_data: dict) -> List[DailyMean]:
    """
    Parse daily mean JSON data into list of DailyMean objects.
    
    Args:
        json_data: JSON response from API
        
    Returns:
        List of DailyMean objects
    """
    features = json_data.get('features', [])
    
    if not features:
        return []
    
    daily_means = []
    for feature in features:
        try:
            daily_mean = DailyMean.from_environment_canada_daily(feature)
            daily_means.append(daily_mean)
        except (KeyError, TypeError, ValueError) as e:
            print(f"Warning: Skipping invalid reading: {e}")
            continue
    
    return daily_means


def display_summary(daily_means: List[DailyMean]) -> None:
    """Display summary statistics of daily mean data."""
    if not daily_means:
        print("\nNo data to display")
        return
    
    levels = [d.level for d in daily_means if d.level is not None]
    discharges = [d.discharge for d in daily_means if d.discharge is not None]
    
    print("\n" + "=" * 60)
    print("DAILY MEAN DATA SUMMARY")
    print("=" * 60)
    print(f"Total Days:         {len(daily_means)}")
    print(f"Date Range:         {daily_means[0].date} to {daily_means[-1].date}")
    
    if levels:
        print(f"\nWater Level (m):")
        print(f"  Most Recent:      {levels[-1]:.2f}")
        print(f"  Minimum:          {min(levels):.2f}")
        print(f"  Maximum:          {max(levels):.2f}")
        print(f"  Average:          {sum(levels)/len(levels):.2f}")
    
    if discharges:
        print(f"\nDischarge (m³/s):")
        print(f"  Most Recent:      {discharges[-1]:.2f}")
        print(f"  Minimum:          {min(discharges):.2f}")
        print(f"  Maximum:          {max(discharges):.2f}")
        print(f"  Average:          {sum(discharges)/len(discharges):.2f}")
    
    print("=" * 60 + "\n")


def display_recent_days(daily_means: List[DailyMean], count: int = 10) -> None:
    """Display the most recent daily readings."""
    if not daily_means:
        return
    
    recent = daily_means[-count:] if len(daily_means) > count else daily_means
    
    print(f"\nMost Recent {len(recent)} Days:")
    print("-" * 70)
    print(f"{'Date':<12} {'Level (m)':<12} {'Discharge (m³/s)':<18}")
    print("-" * 70)
    
    for daily in recent:
        level = f"{daily.level:.2f}" if daily.level is not None else 'N/A'
        discharge = f"{daily.discharge:.2f}" if daily.discharge is not None else 'N/A'
        print(f"{daily.date:<12} {level:<12} {discharge:<18}")
    
    print("-" * 70 + "\n")


def display_monthly_summary(daily_means: List[DailyMean]) -> None:
    """Display monthly averages."""
    if not daily_means:
        return
    
    # Group by month
    monthly_data = {}
    for daily in daily_means:
        month = daily.date[:7]  # YYYY-MM
        if month not in monthly_data:
            monthly_data[month] = {'levels': [], 'discharges': []}
        
        if daily.level is not None:
            monthly_data[month]['levels'].append(daily.level)
        if daily.discharge is not None:
            monthly_data[month]['discharges'].append(daily.discharge)
    
    print("\nMonthly Averages:")
    print("-" * 70)
    print(f"{'Month':<12} {'Avg Level (m)':<16} {'Avg Discharge (m³/s)':<20}")
    print("-" * 70)
    
    for month in sorted(monthly_data.keys()):
        data = monthly_data[month]
        avg_level = sum(data['levels']) / len(data['levels']) if data['levels'] else None
        avg_discharge = sum(data['discharges']) / len(data['discharges']) if data['discharges'] else None
        
        level_str = f"{avg_level:.2f}" if avg_level is not None else 'N/A'
        discharge_str = f"{avg_discharge:.2f}" if avg_discharge is not None else 'N/A'
        
        print(f"{month:<12} {level_str:<16} {discharge_str:<20}")
    
    print("-" * 70 + "\n")


def export_to_csv(daily_means: List[DailyMean], station_id: str) -> None:
    """Export daily means to a CSV file."""
    if not daily_means:
        return
    
    start_date = daily_means[0].date.replace('-', '')
    end_date = daily_means[-1].date.replace('-', '')
    filename = f"daily_means_{station_id}_{start_date}_{end_date}.csv"
    
    try:
        with open(filename, 'w') as f:
            # Write header
            f.write("date,station_id,level_m,discharge_m3s\n")
            
            # Write data
            for daily in daily_means:
                f.write(f"{daily.date},{daily.station_id},")
                f.write(f"{daily.level if daily.level is not None else ''},")
                f.write(f"{daily.discharge if daily.discharge is not None else ''}\n")
        
        print(f"✓ Data exported to {filename}")
    except IOError as e:
        print(f"✗ Error exporting to CSV: {e}")


def main():
    """Main entry point."""
    if len(sys.argv) < 4:
        print("Usage: python fetch_daily_means.py <station_id> <start_date> <end_date>")
        print("Example: python fetch_daily_means.py 08GA072 2024-01-01 2024-12-31")
        sys.exit(1)
    
    station_id = sys.argv[1]
    start_date = sys.argv[2]
    end_date = sys.argv[3]
    
    # Validate date format
    try:
        datetime.strptime(start_date, '%Y-%m-%d')
        datetime.strptime(end_date, '%Y-%m-%d')
    except ValueError:
        print("Error: Dates must be in YYYY-MM-DD format")
        sys.exit(1)
    
    # Fetch daily mean data
    daily_means = fetch_daily_means(station_id, start_date, end_date)
    
    if daily_means:
        display_summary(daily_means)
        display_recent_days(daily_means, count=10)
        display_monthly_summary(daily_means)
        
        # Ask if user wants to export
        response = input("Export to CSV? (y/n): ").lower()
        if response == 'y':
            export_to_csv(daily_means, station_id)
        
        sys.exit(0)
    else:
        sys.exit(1)


if __name__ == "__main__":
    main()
