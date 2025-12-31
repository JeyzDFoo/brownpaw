import firebase_admin
from firebase_admin import credentials, firestore
import json
import sys
from datetime import datetime

# Initialize Firebase
try:
    firebase_admin.get_app()
except ValueError:
    cred = credentials.Certificate('../firebase-service-account.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def import_to_firestore(json_file='bc_whitewater_all_data.json', dry_run=False):
    """Import scraped BC Whitewater data to Firestore
    
    Args:
        json_file: Path to the JSON file with scraped data
        dry_run: If True, just print what would be imported without actually importing
    """
    print(f"Loading data from {json_file}...")
    
    with open(json_file, 'r') as f:
        data = json.load(f)
    
    reaches = data['reaches']
    print(f"Found {len(reaches)} reaches to import")
    
    if dry_run:
        print("\n🔍 DRY RUN MODE - No data will be written\n")
    
    imported = 0
    failed = []
    
    for i, reach_data in enumerate(reaches, 1):
        try:
            # Create document ID from slug or river name
            doc_id = reach_data.get('slug') or reach_data['title'].lower().replace(' ', '-')
            
            # Prepare Firestore document
            firestore_doc = {
                'riverId': doc_id,
                'name': reach_data['title'],
                'river': reach_data['title'].split(' - ')[0] if ' - ' in reach_data['title'] else reach_data['title'],
                'region': reach_data['region'],
                'difficultyClass': reach_data['class'],
                'description': reach_data['description'],
                'estimatedTime': reach_data.get('time'),
                'season': reach_data.get('season'),
                'flowUnit': 'cms',
                'source': 'bcwhitewater.org',
                'sourceUrl': reach_data['url'],
                'createdBy': 'bcwhitewater-scraper',
                'createdAt': firestore.SERVER_TIMESTAMP,
                'updatedAt': firestore.SERVER_TIMESTAMP,
            }
            
            # Add optional fields
            if reach_data.get('scouting'):
                firestore_doc['scouting'] = reach_data['scouting']
            
            if reach_data.get('fullText'):
                firestore_doc['fullText'] = reach_data['fullText']
            
            # Add gauge station info
            if reach_data.get('gauge_station'):
                firestore_doc['gaugeStation'] = reach_data['gauge_station']
                # Also set stationId if we have the code
                if reach_data['gauge_station'].get('code'):
                    firestore_doc['stationId'] = reach_data['gauge_station']['code']
            
            # Add put-in coordinates
            if reach_data.get('put_in'):
                put_in = reach_data['put_in']
                if put_in.get('latitude') and put_in.get('longitude'):
                    firestore_doc['putInCoordinates'] = {
                        'latitude': put_in['latitude'],
                        'longitude': put_in['longitude']
                    }
                if put_in.get('description'):
                    firestore_doc['putIn'] = put_in['description']
            
            # Add take-out coordinates
            if reach_data.get('take_out'):
                take_out = reach_data['take_out']
                if take_out.get('latitude') and take_out.get('longitude'):
                    firestore_doc['takeOutCoordinates'] = {
                        'latitude': take_out['latitude'],
                        'longitude': take_out['longitude']
                    }
                if take_out.get('description'):
                    firestore_doc['takeOut'] = take_out['description']
            
            # Add hazards as list
            hazards_list = []
            if reach_data.get('hazards'):
                if isinstance(reach_data['hazards'], list):
                    hazards_list = reach_data['hazards']
                else:
                    hazards_list = [reach_data['hazards']]
            
            if hazards_list:
                firestore_doc['hazards'] = hazards_list
            
            # Add images
            if reach_data.get('images'):
                firestore_doc['images'] = reach_data['images']
            
            if dry_run:
                print(f"\n[{i}/{len(reaches)}] Would import: {doc_id}")
                print(f"  Name: {firestore_doc['name']}")
                print(f"  Region: {firestore_doc['region']}")
                print(f"  Difficulty: {firestore_doc['difficultyClass']}")
                if firestore_doc.get('gaugeStation'):
                    print(f"  Gauge: {firestore_doc['gaugeStation']['name']} ({firestore_doc['gaugeStation']['code']})")
                if firestore_doc.get('images'):
                    print(f"  Images: {len(firestore_doc['images'])}")
                if firestore_doc.get('description'):
                    print(f"  Description: {firestore_doc['description'][:100]}...")
            else:
                # Write to Firestore
                db.collection('river_runs').document(doc_id).set(firestore_doc)
                print(f"[{i}/{len(reaches)}] ✓ Imported: {firestore_doc['name']}")
                imported += 1
                
        except Exception as e:
            print(f"[{i}/{len(reaches)}] ✗ Failed to import {reach_data.get('title', 'unknown')}: {e}")
            failed.append({
                'reach': reach_data.get('title'),
                'error': str(e)
            })
    
    print(f"\n{'='*60}")
    if dry_run:
        print("DRY RUN COMPLETE")
        print(f"Would import: {len(reaches) - len(failed)} reaches")
    else:
        print("IMPORT COMPLETE")
        print(f"Successfully imported: {imported}")
    print(f"Failed: {len(failed)}")
    print(f"{'='*60}")
    
    if failed:
        print("\nFailed imports:")
        for item in failed:
            print(f"  - {item['reach']}: {item['error']}")

if __name__ == '__main__':
    import sys
    
    # Check if dry-run flag is passed
    dry_run = '--dry-run' in sys.argv
    
    if dry_run:
        print("Running in DRY RUN mode...\n")
    
    import_to_firestore(
        json_file='bc_whitewater_all_data.json',
        dry_run=dry_run
    )
