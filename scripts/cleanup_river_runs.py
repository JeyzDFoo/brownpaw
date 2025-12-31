"""
Cleanup script for the river_runs collection in Firestore.

This script helps maintain data quality by:
- Removing duplicate entries
- Deleting test/invalid data
- Fixing malformed documents
- Removing orphaned or deprecated runs

Usage:
    python cleanup_river_runs.py --dry-run  # Preview changes without modifying
    python cleanup_river_runs.py --delete-all  # Delete all documents (dangerous!)
    python cleanup_river_runs.py --remove-duplicates  # Remove duplicate runs
    python cleanup_river_runs.py --fix-fields  # Fix missing or malformed fields
"""

import argparse
import firebase_admin
from firebase_admin import credentials, firestore
from typing import List, Dict, Any, Set
from datetime import datetime
import json


def initialize_firebase():
    """Initialize Firebase Admin SDK."""
    try:
        firebase_admin.get_app()
    except ValueError:
        # Try to use service account credentials
        try:
            cred = credentials.Certificate('firebase-service-account.json')
            firebase_admin.initialize_app(cred)
            print("✓ Firebase initialized with service account")
        except FileNotFoundError:
            # Fall back to application default credentials
            firebase_admin.initialize_app()
            print("✓ Firebase initialized with default credentials")


def get_all_river_runs(db) -> List[Dict[str, Any]]:
    """Fetch all documents from river_runs collection."""
    runs_ref = db.collection('river_runs')
    docs = runs_ref.stream()
    
    runs = []
    for doc in docs:
        data = doc.to_dict()
        data['_id'] = doc.id
        runs.append(data)
    
    return runs


def find_duplicates(runs: List[Dict[str, Any]]) -> Dict[str, List[str]]:
    """Find duplicate runs based on name and river."""
    seen = {}
    duplicates = {}
    
    for run in runs:
        name = run.get('name', '').strip().lower()
        river = run.get('river', '').strip().lower()
        key = f"{river}:{name}"
        
        if key in seen:
            if key not in duplicates:
                duplicates[key] = [seen[key]]
            duplicates[key].append(run['_id'])
        else:
            seen[key] = run['_id']
    
    return duplicates


def find_invalid_runs(runs: List[Dict[str, Any]]) -> List[str]:
    """Find runs with missing required fields."""
    invalid = []
    required_fields = ['name']
    
    for run in runs:
        # Check for required fields
        if not any(run.get(field) for field in required_fields):
            invalid.append(run['_id'])
            continue
        
        # Check for empty or whitespace-only names
        name = run.get('name', '').strip()
        if not name or name.lower() in ['test', 'delete', 'temp', 'unnamed']:
            invalid.append(run['_id'])
    
    return invalid


def print_summary(runs: List[Dict[str, Any]]):
    """Print a summary of the river_runs collection."""
    print(f"\n{'='*60}")
    print(f"RIVER RUNS COLLECTION SUMMARY")
    print(f"{'='*60}")
    print(f"Total documents: {len(runs)}")
    
    # Count by river
    rivers = {}
    for run in runs:
        river = run.get('river', 'Unknown')
        rivers[river] = rivers.get(river, 0) + 1
    
    print(f"\nRuns by river:")
    for river, count in sorted(rivers.items(), key=lambda x: x[1], reverse=True):
        print(f"  {river}: {count}")
    
    # Count by difficulty class
    difficulties = {}
    for run in runs:
        diff = run.get('difficultyClass', 'Unknown')
        difficulties[diff] = difficulties.get(diff, 0) + 1
    
    print(f"\nRuns by difficulty class:")
    for diff, count in sorted(difficulties.items()):
        print(f"  Class {diff}: {count}")
    
    # Show runs with missing fields
    missing_fields = {
        'name': 0,
        'river': 0,
        'difficultyClass': 0,
        'stationId': 0
    }
    
    for run in runs:
        for field in missing_fields:
            if not run.get(field):
                missing_fields[field] += 1
    
    print(f"\nDocuments missing fields:")
    for field, count in missing_fields.items():
        if count > 0:
            print(f"  {field}: {count}")


def delete_all_runs(db, dry_run: bool = True):
    """Delete all documents in river_runs collection."""
    runs_ref = db.collection('river_runs')
    docs = runs_ref.stream()
    
    count = 0
    for doc in docs:
        if dry_run:
            print(f"[DRY RUN] Would delete: {doc.id}")
        else:
            doc.reference.delete()
            print(f"Deleted: {doc.id}")
        count += 1
    
    if dry_run:
        print(f"\n[DRY RUN] Would delete {count} documents")
    else:
        print(f"\n✓ Deleted {count} documents")


def remove_duplicates(db, runs: List[Dict[str, Any]], dry_run: bool = True):
    """Remove duplicate river runs, keeping the first occurrence."""
    duplicates = find_duplicates(runs)
    
    if not duplicates:
        print("No duplicates found!")
        return
    
    print(f"\nFound {len(duplicates)} sets of duplicates:")
    
    total_to_delete = 0
    for key, doc_ids in duplicates.items():
        print(f"\n  {key}:")
        print(f"    Keeping: {doc_ids[0]}")
        print(f"    Deleting: {', '.join(doc_ids[1:])}")
        total_to_delete += len(doc_ids) - 1
        
        if not dry_run:
            for doc_id in doc_ids[1:]:
                db.collection('river_runs').document(doc_id).delete()
    
    if dry_run:
        print(f"\n[DRY RUN] Would delete {total_to_delete} duplicate documents")
    else:
        print(f"\n✓ Deleted {total_to_delete} duplicate documents")


def remove_invalid_runs(db, runs: List[Dict[str, Any]], dry_run: bool = True):
    """Remove runs with missing or invalid data."""
    invalid = find_invalid_runs(runs)
    
    if not invalid:
        print("No invalid runs found!")
        return
    
    print(f"\nFound {len(invalid)} invalid runs:")
    for doc_id in invalid:
        run = next(r for r in runs if r['_id'] == doc_id)
        print(f"  {doc_id}: name='{run.get('name', 'N/A')}', river='{run.get('river', 'N/A')}'")
        
        if not dry_run:
            db.collection('river_runs').document(doc_id).delete()
    
    if dry_run:
        print(f"\n[DRY RUN] Would delete {len(invalid)} invalid documents")
    else:
        print(f"\n✓ Deleted {len(invalid)} invalid documents")


def fix_fields(db, runs: List[Dict[str, Any]], dry_run: bool = True):
    """Fix missing or malformed fields in river runs."""
    fixed_count = 0
    
    for run in runs:
        doc_id = run['_id']
        updates = {}
        
        # Fix empty strings to None
        for field in ['river', 'difficultyClass', 'stationId', 'description']:
            if field in run and run[field] == '':
                updates[field] = None
        
        # Standardize difficulty class format
        if 'difficultyClass' in run and run['difficultyClass']:
            diff = str(run['difficultyClass']).strip().upper()
            # Remove "CLASS" prefix if present
            diff = diff.replace('CLASS', '').strip()
            if diff != run['difficultyClass']:
                updates['difficultyClass'] = diff
        
        # Trim whitespace from strings
        for field in ['name', 'river', 'description']:
            if field in run and isinstance(run[field], str):
                trimmed = run[field].strip()
                if trimmed != run[field]:
                    updates[field] = trimmed
        
        if updates:
            print(f"\n{doc_id}: {run.get('name', 'N/A')}")
            for field, value in updates.items():
                print(f"  {field}: '{run.get(field)}' → '{value}'")
            
            if not dry_run:
                db.collection('river_runs').document(doc_id).update(updates)
            
            fixed_count += 1
    
    if fixed_count == 0:
        print("No fields need fixing!")
    elif dry_run:
        print(f"\n[DRY RUN] Would fix {fixed_count} documents")
    else:
        print(f"\n✓ Fixed {fixed_count} documents")


def main():
    parser = argparse.ArgumentParser(
        description='Cleanup the river_runs Firestore collection'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview changes without modifying the database'
    )
    parser.add_argument(
        '--delete-all',
        action='store_true',
        help='Delete all documents in the collection (use with caution!)'
    )
    parser.add_argument(
        '--remove-duplicates',
        action='store_true',
        help='Remove duplicate river runs'
    )
    parser.add_argument(
        '--remove-invalid',
        action='store_true',
        help='Remove runs with missing or invalid data'
    )
    parser.add_argument(
        '--fix-fields',
        action='store_true',
        help='Fix malformed or inconsistent field values'
    )
    parser.add_argument(
        '--summary',
        action='store_true',
        help='Show collection summary only'
    )
    
    args = parser.parse_args()
    
    # Initialize Firebase
    initialize_firebase()
    db = firestore.client()
    
    # Fetch all runs
    print("Fetching river runs...")
    runs = get_all_river_runs(db)
    
    # Always show summary
    print_summary(runs)
    
    # Exit early if only summary requested
    if args.summary:
        return
    
    # Perform requested operations
    if args.delete_all:
        if not args.dry_run:
            confirm = input("\n⚠️  Are you sure you want to delete ALL river runs? (yes/no): ")
            if confirm.lower() != 'yes':
                print("Aborted.")
                return
        delete_all_runs(db, args.dry_run)
    
    if args.remove_duplicates:
        remove_duplicates(db, runs, args.dry_run)
    
    if args.remove_invalid:
        remove_invalid_runs(db, runs, args.dry_run)
    
    if args.fix_fields:
        fix_fields(db, runs, args.dry_run)
    
    # If no action specified, show help
    if not any([args.delete_all, args.remove_duplicates, 
                args.remove_invalid, args.fix_fields]):
        print("\nNo action specified. Use --help to see available options.")
        print("Tip: Start with --dry-run to preview changes.")


if __name__ == '__main__':
    main()
