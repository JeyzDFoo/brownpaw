#!/usr/bin/env python3
"""
View Station Data - Helper script to view station_data in Firestore.

Usage:
    python3 view_station_data.py [station_id]
    python3 view_station_data.py                  # List all stations
    python3 view_station_data.py 08HD006          # View specific station
    python3 view_station_data.py 08HD006 2024     # View specific year
"""

import sys
import os
from pathlib import Path
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent))
from models import Provider


def init_firebase():
    """Initialize Firebase Admin SDK."""
    try:
        firebase_admin.get_app()
    except ValueError:
        script_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(script_dir)
        cred_path = os.path.join(project_root, 'firebase-service-account.json')
        
        if not os.path.exists(cred_path):
            raise FileNotFoundError(f"Firebase credentials not found at {cred_path}")
        
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
    
    return firestore.client()


def list_all_stations(db):
    """List all stations in station_data collection."""
    print("=" * 70)
    print("ALL STATIONS IN FIRESTORE")
    print("=" * 70)
    
    station_data_ref = db.collection('station_data')
    docs = station_data_ref.list_documents()
    
    stations = []
    for doc_ref in docs:
        # Get metadata
        metadata_ref = doc_ref.collection('metadata').document('info')
        metadata_doc = metadata_ref.get()
        
        if metadata_doc.exists:
            metadata = metadata_doc.to_dict()
            stations.append({
                'doc_id': doc_ref.id,
                'station_id': metadata.get('station_id'),
                'station_name': metadata.get('station_name'),
                'provider': metadata.get('provider'),
                'last_updated': metadata.get('last_updated'),
            })
    
    if not stations:
        print("No stations found.")
        return
    
    print(f"\nFound {len(stations)} station(s):\n")
    
    for station in sorted(stations, key=lambda x: x['station_id']):
        print(f"Station ID: {station['station_id']}")
        print(f"  Name: {station['station_name']}")
        print(f"  Provider: {station['provider']}")
        if station['last_updated']:
            last_updated = station['last_updated'].strftime('%Y-%m-%d %H:%M:%S')
            print(f"  Last Updated: {last_updated}")
        print()


def view_station(db, station_id, year=None):
    """View data for a specific station."""
    doc_id = f"{Provider.ENVIRONMENT_CANADA}_{station_id}"
    
    print("=" * 70)
    print(f"STATION: {station_id}")
    print("=" * 70)
    
    # Get metadata
    metadata_ref = (
        db.collection('station_data')
        .document(doc_id)
        .collection('metadata')
        .document('info')
    )
    
    metadata_doc = metadata_ref.get()
    if not metadata_doc.exists:
        print(f"Station {station_id} not found in Firestore.")
        return
    
    metadata = metadata_doc.to_dict()
    
    print("\nMETADATA:")
    print(f"  Station ID: {metadata.get('station_id')}")
    print(f"  Station Name: {metadata.get('station_name')}")
    print(f"  Provider: {metadata.get('provider')}")
    print(f"  First Fetch: {metadata.get('first_data_fetch')}")
    print(f"  Last Updated: {metadata.get('last_updated')}")
    print(f"  Active: {metadata.get('is_active')}")
    
    # Get readings
    readings_ref = (
        db.collection('station_data')
        .document(doc_id)
        .collection('readings')
    )
    
    if year:
        # Get specific year
        year_doc = readings_ref.document(str(year)).get()
        if year_doc.exists:
            data = year_doc.to_dict()
            daily_readings = data.get('daily_readings', {})
            print(f"\nREADINGS FOR {year}:")
            print(f"  Total days: {len(daily_readings)}")
            
            # Show first and last few readings
            sorted_dates = sorted(daily_readings.keys())
            if sorted_dates:
                print(f"  Date range: {sorted_dates[0]} to {sorted_dates[-1]}")
                
                print("\n  First 5 readings:")
                for date in sorted_dates[:5]:
                    reading = daily_readings[date]
                    discharge = reading.get('mean_discharge', 'N/A')
                    level = reading.get('mean_level', 'N/A')
                    print(f"    {date}: Discharge={discharge} m³/s, Level={level} m")
                
                if len(sorted_dates) > 5:
                    print("\n  Last 5 readings:")
                    for date in sorted_dates[-5:]:
                        reading = daily_readings[date]
                        discharge = reading.get('mean_discharge', 'N/A')
                        level = reading.get('mean_level', 'N/A')
                        print(f"    {date}: Discharge={discharge} m³/s, Level={level} m")
        else:
            print(f"\nNo data found for year {year}")
    else:
        # List all years
        year_docs = readings_ref.stream()
        years_data = []
        
        for doc in year_docs:
            data = doc.to_dict()
            daily_readings = data.get('daily_readings', {})
            years_data.append({
                'year': int(doc.id),
                'count': len(daily_readings),
                'updated_at': data.get('updated_at'),
            })
        
        if years_data:
            print(f"\nREADINGS BY YEAR:")
            for year_info in sorted(years_data, key=lambda x: x['year']):
                updated = year_info['updated_at'].strftime('%Y-%m-%d %H:%M:%S') if year_info['updated_at'] else 'N/A'
                print(f"  {year_info['year']}: {year_info['count']} days (updated: {updated})")
            
            print(f"\nTo view specific year: python3 view_station_data.py {station_id} <year>")
        else:
            print("\nNo readings data found.")


def main():
    db = init_firebase()
    
    if len(sys.argv) == 1:
        # No arguments - list all stations
        list_all_stations(db)
    elif len(sys.argv) == 2:
        # Station ID provided - show station details
        station_id = sys.argv[1]
        view_station(db, station_id)
    elif len(sys.argv) == 3:
        # Station ID and year provided
        station_id = sys.argv[1]
        year = int(sys.argv[2])
        view_station(db, station_id, year)
    else:
        print("Usage:")
        print("  python3 view_station_data.py                  # List all stations")
        print("  python3 view_station_data.py <station_id>     # View station details")
        print("  python3 view_station_data.py <station_id> <year>  # View specific year")


if __name__ == '__main__':
    main()
