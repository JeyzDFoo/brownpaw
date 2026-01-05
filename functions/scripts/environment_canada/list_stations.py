#!/usr/bin/env python3
"""
List common Environment Canada hydrometric stations for whitewater rivers.

This is a curated list of stations commonly used for kayaking.
For a complete list, visit: https://wateroffice.ec.gc.ca
"""

import sys
from typing import List, Dict
from pathlib import Path

# Add parent directory to path to import models
sys.path.insert(0, str(Path(__file__).parent.parent))
from models import Station, Provider


def create_station_object(station_dict: Dict) -> Station:
    """Create a Station model object from dictionary."""
    return Station(
        provider=Provider.ENVIRONMENT_CANADA,
        station_id=station_dict['station_id'],
        station_name=station_dict['name'],
        country='CA',
        province_or_state=station_dict['province'],
        latitude=station_dict['latitude'],
        longitude=station_dict['longitude'],
        active=True,
        provider_metadata={
            'river': station_dict['river'],
            'popular_runs': station_dict['popular_runs']
        }
    )


# Curated list of popular whitewater river monitoring stations
STATIONS = [
    {
        'station_id': '01AF009',
        'name': 'Madawaska River at Arnprior',
        'river': 'Madawaska River',
        'province': 'Ontario',
        'latitude': 45.4333,
        'longitude': -76.3500,
        'popular_runs': ['Palmer Rapids', 'Mountain Chute']
    },
    {
        'station_id': '02KB001',
        'name': 'Kicking Horse River at Golden',
        'river': 'Kicking Horse River',
        'province': 'British Columbia',
        'latitude': 51.2833,
        'longitude': -116.9667,
        'popular_runs': ['Lower Canyon']
    },
    {
        'station_id': '05BJ010',
        'name': 'Bow River at Banff',
        'river': 'Bow River',
        'province': 'Alberta',
        'latitude': 51.1833,
        'longitude': -115.5667,
        'popular_runs': ['Canmore Run']
    },
    {
        'station_id': '08HB002',
        'name': 'Thompson River at Spences Bridge',
        'river': 'Thompson River',
        'province': 'British Columbia',
        'latitude': 50.4167,
        'longitude': -121.3500,
        'popular_runs': ['Frog Rapid Section']
    },
    {
        'station_id': '08NM116',
        'name': 'Chilliwack River at Vedder Crossing',
        'river': 'Chilliwack River',
        'province': 'British Columbia',
        'latitude': 49.0667,
        'longitude': -122.0167,
        'popular_runs': ['Upper Chilliwack']
    },
    {
        'station_id': '02DD008',
        'name': 'Rouge River above Chute Wilson',
        'river': 'Rouge River',
        'province': 'Quebec',
        'latitude': 46.1167,
        'longitude': -74.4333,
        'popular_runs': ['Seven Sisters']
    },
    {
        'station_id': '02OJ007',
        'name': 'Jacques-Cartier River near Donnacona',
        'river': 'Jacques-Cartier River',
        'province': 'Quebec',
        'latitude': 46.7167,
        'longitude': -71.7167,
        'popular_runs': ['Canyon Section']
    },
]


def list_all_stations() -> None:
    """Display all stations in a formatted table."""
    print("\n" + "=" * 100)
    print("ENVIRONMENT CANADA HYDROMETRIC STATIONS - WHITEWATER RIVERS")
    print("=" * 100)
    print(f"{'Station ID':<12} {'River Name':<25} {'Location':<30} {'Province':<10}")
    print("-" * 100)
    
    for station in sorted(STATIONS, key=lambda x: x['province']):
        print(f"{station['station_id']:<12} {station['river']:<25} "
              f"{station['name'][:30]:<30} {station['province']:<10}")
    
    print("-" * 100)
    print(f"Total Stations: {len(STATIONS)}\n")


def list_by_province(province: str) -> None:
    """Display stations filtered by province."""
    filtered = [s for s in STATIONS if s['province'].lower() == province.lower()]
    
    if not filtered:
        print(f"\nNo stations found for province: {province}\n")
        return
    
    print(f"\n{'=' * 100}")
    print(f"STATIONS IN {province.upper()}")
    print("=" * 100)
    print(f"{'Station ID':<12} {'River Name':<25} {'Popular Runs':<40}")
    print("-" * 100)
    
    for station in filtered:
        runs = ', '.join(station['popular_runs'])
        print(f"{station['station_id']:<12} {station['river']:<25} {runs:<40}")
    
    print("-" * 100)
    print(f"Total: {len(filtered)} stations\n")


def get_station_details(station_id: str) -> None:
    """Display detailed information for a specific station."""
    station = next((s for s in STATIONS if s['station_id'] == station_id), None)
    
    if not station:
        print(f"\nStation {station_id} not found in database.\n")
        return
    
    # Create Station model object
    station_obj = create_station_object(station)
    
    print("\n" + "=" * 60)
    print("STATION DETAILS")
    print("=" * 60)
    print(f"Station ID:      {station['station_id']}")
    print(f"Station Name:    {station['name']}")
    print(f"River:           {station['river']}")
    print(f"Province:        {station['province']}")
    print(f"Coordinates:     {station['latitude']}, {station['longitude']}")
    print(f"\nPopular Runs:")
    for run in station['popular_runs']:
        print(f"  - {run}")
    print(f"\nFirestore Doc:   {station_obj.document_id}")
    print(f"Provider:        {station_obj.provider.value}")
    print("=" * 60 + "\n")


def main():
    """Main entry point."""
    import sys
    
    if len(sys.argv) > 1:
        command = sys.argv[1].lower()
        
        if command == 'province' and len(sys.argv) > 2:
            list_by_province(sys.argv[2])
        elif command == 'details' and len(sys.argv) > 2:
            get_station_details(sys.argv[2])
        else:
            print("Usage:")
            print("  python list_stations.py                    - List all stations")
            print("  python list_stations.py province <name>    - Filter by province")
            print("  python list_stations.py details <id>       - Show station details")
            print("\nExamples:")
            print("  python list_stations.py province Ontario")
            print("  python list_stations.py details 01AF009")
    else:
        list_all_stations()
        
        print("\nTip: Use 'python list_stations.py province <name>' to filter by province")
        print("     Or 'python list_stations.py details <id>' for station details\n")


if __name__ == "__main__":
    main()
