#!/usr/bin/env python3
"""
Upload BC Whitewater data to Firestore river_runs collection.
"""

import json
import os
import re
from typing import Dict, Any, Optional
import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime

# Initialize Firebase Admin SDK
try:
    firebase_admin.get_app()
except ValueError:
    # Get the path to the firebase service account file
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    cred_path = os.path.join(project_root, 'firebase-service-account.json')
    
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)

db = firestore.client()


def slugify(text: str) -> str:
    """Convert text to a slug format for document IDs."""
    # Convert to lowercase
    text = text.lower()
    # Replace spaces and special chars with hyphens
    text = re.sub(r'[^\w\s-]', '', text)
    text = re.sub(r'[-\s]+', '-', text)
    return text.strip('-')


def parse_difficulty_class(difficulty_class: str) -> tuple[Optional[int], Optional[int]]:
    """
    Parse difficulty class string to extract min and max numeric values.
    
    Examples:
        "III+" -> (3, 3)
        "III-IV" -> (3, 4)
        "IV/IV+" -> (4, 4)
        "II-III (IV)" -> (2, 4)
    """
    if not difficulty_class:
        return None, None
    
    # Map roman numerals to integers
    roman_to_int = {
        'I': 1, 'II': 2, 'III': 3, 'IV': 4, 'V': 5, 'VI': 6
    }
    
    # Extract all roman numerals from the string
    roman_pattern = r'\b(VI|V|IV|III|II|I)\b'
    matches = re.findall(roman_pattern, difficulty_class.upper())
    
    if not matches:
        return None, None
    
    # Convert to integers
    values = [roman_to_int.get(m, 0) for m in matches if m in roman_to_int]
    
    if not values:
        return None, None
    
    return min(values), max(values)


def convert_reach_to_river_run(reach: Dict[str, Any]) -> Dict[str, Any]:
    """Convert BC Whitewater reach data to Firestore river_run format."""
    
    # Parse difficulty
    diff_min, diff_max = parse_difficulty_class(reach.get('class', ''))
    
    # Create document
    doc = {
        'name': reach['title'],
        'river': reach['title'],  # BC Whitewater uses title as river name
        'province': reach.get('province', 'BC'),
        'difficultyClass': reach.get('class', ''),
        'description': reach.get('description', ''),
        'flowUnit': 'cms',
        'source': 'bcwhitewater.org',
        'sourceUrl': reach.get('url', ''),
        'createdBy': 'bcwhitewater_import',
        'createdAt': firestore.SERVER_TIMESTAMP,
        'updatedAt': firestore.SERVER_TIMESTAMP,
    }
    
    # Add optional fields
    if diff_min is not None:
        doc['difficultyMin'] = diff_min
    if diff_max is not None:
        doc['difficultyMax'] = diff_max
    
    if reach.get('time'):
        doc['estimatedTime'] = reach['time']
    
    if reach.get('season'):
        doc['season'] = reach['season']
    
    if reach.get('scouting'):
        doc['scouting'] = reach['scouting']
    
    if reach.get('full_text'):
        doc['fullText'] = reach['full_text']
    
    # Put-in location
    if reach.get('put_in'):
        put_in = reach['put_in']
        if put_in.get('description'):
            doc['putIn'] = put_in['description']
        if put_in.get('latitude') and put_in.get('longitude'):
            doc['putInCoordinates'] = {
                'latitude': put_in['latitude'],
                'longitude': put_in['longitude']
            }
    
    # Take-out location
    if reach.get('take_out'):
        take_out = reach['take_out']
        if take_out.get('description'):
            doc['takeOut'] = take_out['description']
        if take_out.get('latitude') and take_out.get('longitude'):
            doc['takeOutCoordinates'] = {
                'latitude': take_out['latitude'],
                'longitude': take_out['longitude']
            }
    
    # Gauge station
    if reach.get('gauge_station'):
        station = reach['gauge_station']
        if station and station.get('name') and station.get('code'):
            doc['gaugeStation'] = {
                'name': station['name'],
                'code': station['code']
            }
            # Set stationId using the Environment Canada format
            doc['stationId'] = f"environment_canada_{station['code']}"
            doc['hasValidStation'] = True
    
    # Images
    if reach.get('images'):
        # Filter out images without captions or duplicates (thumbnails)
        images = []
        seen_urls = set()
        for img in reach['images']:
            url = img.get('url', '')
            # Skip thumbnail/representation URLs
            if 'representations' in url or url in seen_urls:
                continue
            if url:
                images.append({
                    'url': url,
                    'caption': img.get('caption', '')
                })
                seen_urls.add(url)
        if images:
            doc['images'] = images
    
    # Regional info (BC-specific regions like "Vancouver Island", "Kootenays")
    if reach.get('region'):
        doc['region'] = reach['region']
    
    return doc


def upload_to_firestore(data_file: str, dry_run: bool = False):
    """
    Upload BC Whitewater data to Firestore.
    
    Args:
        data_file: Path to the JSON data file
        dry_run: If True, print what would be uploaded without actually uploading
    """
    # Load the data
    print(f"Loading data from {data_file}...")
    with open(data_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    reaches = data.get('reaches', [])
    print(f"Found {len(reaches)} reaches to upload")
    
    if dry_run:
        print("\n=== DRY RUN MODE - No data will be written ===\n")
    
    # Process each reach
    success_count = 0
    error_count = 0
    skipped_count = 0
    
    for i, reach in enumerate(reaches, 1):
        try:
            # Generate document ID from slug
            slug = reach.get('slug')
            if not slug:
                slug = slugify(reach.get('title', ''))
            
            if not slug:
                print(f"  Skipping reach {i}: No title/slug")
                skipped_count += 1
                continue
            
            # Convert to river_run format
            river_run = convert_reach_to_river_run(reach)
            
            # Print summary
            print(f"{i}/{len(reaches)}: {river_run['name']}")
            print(f"  ID: {slug}")
            print(f"  Difficulty: {river_run['difficultyClass']}")
            if 'gaugeStation' in river_run:
                print(f"  Station: {river_run['gaugeStation']['code']}")
            
            if dry_run:
                # Just show what we would upload
                print(f"  Would upload document with {len(river_run)} fields")
            else:
                # Upload to Firestore
                doc_ref = db.collection('river_runs').document(slug)
                doc_ref.set(river_run)
                print(f"  ✓ Uploaded successfully")
            
            success_count += 1
            
        except Exception as e:
            print(f"  ✗ Error processing reach {i}: {e}")
            error_count += 1
            continue
    
    # Print summary
    print(f"\n{'='*60}")
    print(f"Upload {'simulation ' if dry_run else ''}complete!")
    print(f"  Successful: {success_count}")
    print(f"  Errors: {error_count}")
    print(f"  Skipped: {skipped_count}")
    print(f"  Total: {len(reaches)}")
    print(f"{'='*60}")


if __name__ == '__main__':
    import sys
    
    # Determine mode
    dry_run = '--dry-run' in sys.argv or '-n' in sys.argv
    
    # Path to data file (relative to script directory)
    script_dir = os.path.dirname(os.path.abspath(__file__))
    data_file = os.path.join(script_dir, 'bcwhitewater', 'bc_whitewater_all_data.json')
    
    # Upload
    upload_to_firestore(data_file, dry_run=dry_run)
