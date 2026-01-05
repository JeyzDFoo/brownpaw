"""
Migration script to restructure river_runs as a subcollection under rivers.

This script:
1. Creates a rivers collection with unique river documents
2. Moves each run from the top-level river_runs collection to rivers/{river_id}/river_runs/{run_id}
3. Optionally deletes the old top-level river_runs documents

Data Structure:
Before: river_runs/{run_id} { name, river, difficultyClass, ... }
After:  rivers/{river_id} { name, region, ... }
        rivers/{river_id}/river_runs/{run_id} { name, difficultyClass, ... }

Usage:
    python migrate_runs_to_subcollection.py --dry-run  # Preview changes
    python migrate_runs_to_subcollection.py --migrate  # Perform migration
    python migrate_runs_to_subcollection.py --migrate --delete-old  # Migrate and delete old docs
"""

import argparse
import firebase_admin
from firebase_admin import credentials, firestore
from typing import Dict, Any, Set
from collections import defaultdict
import re


def initialize_firebase():
    """Initialize Firebase Admin SDK."""
    try:
        firebase_admin.get_app()
    except ValueError:
        try:
            cred = credentials.Certificate('../firebase-service-account.json')
            firebase_admin.initialize_app(cred)
            print("✓ Firebase initialized with service account")
        except FileNotFoundError:
            try:
                cred = credentials.Certificate('firebase-service-account.json')
                firebase_admin.initialize_app(cred)
                print("✓ Firebase initialized with service account")
            except FileNotFoundError:
                firebase_admin.initialize_app()
                print("✓ Firebase initialized with default credentials")


def slugify(text: str) -> str:
    """Convert text to a URL-friendly slug."""
    # Convert to lowercase
    text = text.lower()
    # Replace spaces and special chars with hyphens
    text = re.sub(r'[^a-z0-9]+', '-', text)
    # Remove leading/trailing hyphens
    text = text.strip('-')
    return text


def extract_river_name_from_id(doc_id: str, run_name: str) -> str:
    """Extract river name from document ID or run name."""
    # Try to extract from document ID (e.g., "cheakamus-river-upper" -> "Cheakamus River")
    if '-river-' in doc_id:
        parts = doc_id.split('-river-')
        river = parts[0].replace('-', ' ').title() + ' River'
        return river
    elif '-creek-' in doc_id:
        parts = doc_id.split('-creek-')
        river = parts[0].replace('-', ' ').title() + ' Creek'
        return river
    
    # Try to extract from run name (e.g., "Cheakamus River – Upper" -> "Cheakamus River")
    if ' – ' in run_name or ' - ' in run_name:
        separator = ' – ' if ' – ' in run_name else ' - '
        river = run_name.split(separator)[0]
        return river
    
    # Check if run name contains common river/creek patterns
    if 'River' in run_name:
        # Extract up to and including "River"
        parts = run_name.split('River')[0] + 'River'
        return parts.strip()
    elif 'Creek' in run_name:
        parts = run_name.split('Creek')[0] + 'Creek'
        return parts.strip()
    
    # Fallback: use the full name as river name
    return run_name


def extract_river_info(runs: list) -> Dict[str, Dict[str, Any]]:
    """Extract unique rivers from runs and create river documents."""
    rivers = {}
    
    for run in runs:
        # First try the river field
        river_name = run.get('river', '').strip()
        
        # If no river field, try to extract from ID or name
        if not river_name:
            river_name = extract_river_name_from_id(run['_id'], run.get('name', ''))
        
        if not river_name:
            print(f"⚠️  Warning: Run '{run.get('name', run['_id'])}' has no river field")
            continue
        
        # Create a unique ID for the river
        river_id = slugify(river_name)
        
        if river_id not in rivers:
            rivers[river_id] = {
                'name': river_name,
                'region': run.get('region', ''),
                'description': '',
                'runs_count': 0
            }
        
        # Increment run count
        rivers[river_id]['runs_count'] += 1
        
        # Update region if we have more info
        if run.get('region') and not rivers[river_id]['region']:
            rivers[river_id]['region'] = run['region']
    
    return rivers


def preview_migration(db):
    """Preview what the migration will do."""
    print("\n" + "="*60)
    print("MIGRATION PREVIEW (DRY RUN)")
    print("="*60 + "\n")
    
    # Fetch all river runs
    runs_ref = db.collection('river_runs')
    docs = runs_ref.stream()
    
    runs = []
    for doc in docs:
        data = doc.to_dict()
        data['_id'] = doc.id
        runs.append(data)
    
    print(f"📊 Found {len(runs)} runs in river_runs collection\n")
    
    # Extract river info
    rivers = extract_river_info(runs)
    
    print(f"🏞️  Will create {len(rivers)} river documents:\n")
    for river_id, river_data in sorted(rivers.items()):
        print(f"   rivers/{river_id}")
        print(f"      name: {river_data['name']}")
        print(f"      region: {river_data['region'] or '(empty)'}")
        print(f"      runs: {river_data['runs_count']}")
        print()
    
    # Group runs by river
    runs_by_river = defaultdict(list)
    for run in runs:
        # First try the river field
        river_name = run.get('river', '').strip()
        
        # If no river field, try to extract from ID or name
        if not river_name:
            river_name = extract_river_name_from_id(run['_id'], run.get('name', ''))
        
        if river_name:
            river_id = slugify(river_name)
            runs_by_river[river_id].append(run)
    
    print(f"📋 Will migrate {len(runs)} runs to subcollections:\n")
    for river_id, river_runs in sorted(runs_by_river.items()):
        rivers_data = rivers.get(river_id, {})
        print(f"   rivers/{river_id}/river_runs/")
        for run in river_runs:
            print(f"      ├─ {run['_id']} ({run.get('name', 'Unnamed')})")
        print()
    
    # Check for runs without river
    orphaned = [r for r in runs if not r.get('river', '').strip()]
    if orphaned:
        print(f"⚠️  WARNING: {len(orphaned)} runs have no river field:")
        for run in orphaned:
            print(f"      - {run['_id']}: {run.get('name', 'Unnamed')}")
        print()


def perform_migration(db, delete_old: bool = False):
    """Perform the actual migration."""
    print("\n" + "="*60)
    print("PERFORMING MIGRATION")
    print("="*60 + "\n")
    
    # Fetch all river runs
    runs_ref = db.collection('river_runs')
    docs = runs_ref.stream()
    
    runs = []
    for doc in docs:
        data = doc.to_dict()
        data['_id'] = doc.id
        runs.append(data)
    
    print(f"📊 Found {len(runs)} runs to migrate\n")
    
    # Extract and create river documents
    rivers = extract_river_info(runs)
    
    print(f"🏞️  Creating {len(rivers)} river documents...")
    batch = db.batch()
    batch_count = 0
    
    for river_id, river_data in rivers.items():
        river_ref = db.collection('rivers').document(river_id)
        
        # Remove runs_count from the actual document
        doc_data = {k: v for k, v in river_data.items() if k != 'runs_count'}
        
        batch.set(river_ref, doc_data, merge=True)
        batch_count += 1
        
        # Commit batch every 500 operations (Firestore limit)
        if batch_count >= 500:
            batch.commit()
            print(f"   ✓ Committed batch of {batch_count} rivers")
            batch = db.batch()
            batch_count = 0
    
    if batch_count > 0:
        batch.commit()
        print(f"   ✓ Committed final batch of {batch_count} rivers")
    
    print(f"✓ Created {len(rivers)} river documents\n")
    
    # Migrate runs to subcollections
    print(f"📋 Migrating {len(runs)} runs to subcollections...")
    
    batch = db.batch()
    batch_count = 0
    migrated_count = 0
    skipped_count = 0
    
    for run in runs:
        # First try the river field
        river_name = run.get('river', '').strip()
        
        # If no river field, try to extract from ID or name
        if not river_name:
            river_name = extract_river_name_from_id(run['_id'], run.get('name', ''))
        
        if not river_name:
            print(f"   ⚠️  Skipping run {run['_id']} (no river field)")
            skipped_count += 1
            continue
        
        river_id = slugify(river_name)
        run_id = run['_id']
        
        # Create new subcollection document
        new_run_ref = db.collection('rivers').document(river_id).collection('river_runs').document(run_id)
        
        # Copy data (excluding the _id we added)
        run_data = {k: v for k, v in run.items() if k != '_id'}
        
        batch.set(new_run_ref, run_data)
        batch_count += 1
        migrated_count += 1
        
        # If deleting old documents, add to batch
        if delete_old:
            old_run_ref = db.collection('river_runs').document(run_id)
            batch.delete(old_run_ref)
            batch_count += 1
        
        # Commit batch every 500 operations
        if batch_count >= 500:
            batch.commit()
            print(f"   ✓ Committed batch ({migrated_count} migrated)")
            batch = db.batch()
            batch_count = 0
    
    if batch_count > 0:
        batch.commit()
        print(f"   ✓ Committed final batch")
    
    print(f"\n✅ Migration complete!")
    print(f"   Migrated: {migrated_count} runs")
    print(f"   Skipped: {skipped_count} runs")
    if delete_old:
        print(f"   Deleted: {migrated_count} old documents")
    else:
        print(f"   ⚠️  Old river_runs collection still exists (use --delete-old to remove)")


def main():
    parser = argparse.ArgumentParser(
        description='Migrate river_runs to subcollection structure'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview changes without modifying data'
    )
    parser.add_argument(
        '--migrate',
        action='store_true',
        help='Perform the migration'
    )
    parser.add_argument(
        '--delete-old',
        action='store_true',
        help='Delete old river_runs documents after migration (use with --migrate)'
    )
    
    args = parser.parse_args()
    
    # Initialize Firebase
    initialize_firebase()
    db = firestore.client()
    
    if args.dry_run:
        preview_migration(db)
    elif args.migrate:
        if args.delete_old:
            response = input("\n⚠️  WARNING: This will DELETE all documents from river_runs collection after migration.\n"
                           "Are you sure? Type 'yes' to continue: ")
            if response.lower() != 'yes':
                print("Migration cancelled.")
                return
        
        perform_migration(db, delete_old=args.delete_old)
    else:
        print("Please specify --dry-run or --migrate")
        parser.print_help()


if __name__ == '__main__':
    main()
