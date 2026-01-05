#!/usr/bin/env python3
"""
Update Firestore river_runs with extracted gauge station codes.

This script updates the stationId and gaugeStation fields for river_runs
based on the newly extracted station codes.
"""

import json
import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
try:
    firebase_admin.get_app()
except ValueError:
    cred = credentials.Certificate('../../firebase-service-account.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def main():
    # Load updated data
    print("Loading data with extracted station codes...")
    with open('bc_whitewater_all_data_with_stations.json', 'r') as f:
        data = json.load(f)
    
    reaches = data['reaches']
    
    # Count how many have station codes
    with_stations = [
        r for r in reaches 
        if r.get('gauge_station') and isinstance(r.get('gauge_station'), dict) and r['gauge_station'].get('code')
    ]
    print(f"Found {len(with_stations)} reaches with station codes")
    
    updated = 0
    failed = 0
    
    for reach in with_stations:
        try:
            # Get the document ID (slug)
            doc_id = reach.get('slug') or reach['title'].lower().replace(' ', '-')
            
            gauge_station = reach['gauge_station']
            station_code = gauge_station['code']
            
            # Prepare update data
            update_data = {
                'stationId': station_code,
                'gaugeStation': {
                    'code': station_code,
                    'name': gauge_station.get('name', '').strip()
                },
                'updatedAt': firestore.SERVER_TIMESTAMP
            }
            
            # Update Firestore
            doc_ref = db.collection('river_runs').document(doc_id)
            doc_ref.update(update_data)
            
            updated += 1
            print(f"✓ Updated {reach['title'][:50]:50} -> {station_code}")
            
        except Exception as e:
            failed += 1
            print(f"✗ Failed to update {reach.get('title', 'unknown')}: {e}")
    
    print("\n" + "=" * 70)
    print("SUMMARY")
    print("=" * 70)
    print(f"Successfully updated: {updated}")
    print(f"Failed: {failed}")
    print(f"Total: {len(with_stations)}")

if __name__ == '__main__':
    main()
