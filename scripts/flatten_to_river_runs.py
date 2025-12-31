"""
Flatten the data structure - move all runs back to top-level river_runs collection
with river name and region as fields.

This script:
1. Fetches all runs from rivers/{riverId}/river_runs/{runId}
2. Adds river name and region fields to each run
3. Creates documents in top-level river_runs collection
4. Optionally deletes the rivers collection

Usage:
    python flatten_to_river_runs.py --dry-run  # Preview changes
    python flatten_to_river_runs.py --migrate  # Perform migration
    python flatten_to_river_runs.py --migrate --delete-rivers  # Migrate and delete rivers collection
"""

import argparse
import firebase_admin
from firebase_admin import credentials, firestore


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


def preview_migration(db):
    """Preview what the migration will do."""
    print("\n" + "="*60)
    print("MIGRATION PREVIEW (DRY RUN)")
    print("="*60 + "\n")
    
    # Fetch all rivers
    rivers_ref = db.collection('rivers')
    rivers = rivers_ref.stream()
    
    total_runs = 0
    
    for river_doc in rivers:
        river_data = river_doc.to_dict()
        river_name = river_data.get('name', river_doc.id)
        river_region = river_data.get('region', '')
        
        # Fetch runs for this river
        runs_ref = river_doc.reference.collection('river_runs')
        runs = list(runs_ref.stream())
        
        if runs:
            print(f"   {river_name} ({river_region}): {len(runs)} runs")
            total_runs += len(runs)
    
    print(f"\n📊 Summary:")
    print(f"   Total runs to migrate: {total_runs}")
    print(f"\n   Each run will be created as: river_runs/{{runId}}")
    print(f"   With fields: name, river, region, ...")


def apply_migration(db, delete_rivers: bool = False):
    """Flatten the data structure."""
    print("\n" + "="*60)
    print("PERFORMING MIGRATION")
    print("="*60 + "\n")
    
    # Fetch all rivers
    rivers_ref = db.collection('rivers')
    rivers = rivers_ref.stream()
    
    batch = db.batch()
    batch_count = 0
    migrated_count = 0
    river_ids_to_delete = []
    
    for river_doc in rivers:
        river_data = river_doc.to_dict()
        river_name = river_data.get('name', river_doc.id)
        river_region = river_data.get('region', '')
        
        print(f"   Processing {river_name}...")
        
        # Fetch runs for this river
        runs_ref = river_doc.reference.collection('river_runs')
        runs = runs_ref.stream()
        
        for run_doc in runs:
            run_data = run_doc.to_dict()
            
            # Add river name and region to run data
            run_data['river'] = river_name
            run_data['region'] = river_region
            
            # Create in top-level river_runs collection
            new_run_ref = db.collection('river_runs').document(run_doc.id)
            batch.set(new_run_ref, run_data)
            batch_count += 1
            migrated_count += 1
            
            # Commit batch every 500 operations
            if batch_count >= 500:
                batch.commit()
                print(f"      ✓ Committed batch ({migrated_count} migrated)")
                batch = db.batch()
                batch_count = 0
        
        # Track river for deletion
        if delete_rivers:
            river_ids_to_delete.append(river_doc.id)
    
    if batch_count > 0:
        batch.commit()
        print(f"   ✓ Committed final batch")
    
    print(f"\n✅ Migration complete!")
    print(f"   Migrated: {migrated_count} runs to river_runs collection")
    
    # Delete rivers collection if requested
    if delete_rivers:
        print(f"\n🗑️  Deleting rivers collection...")
        batch = db.batch()
        batch_count = 0
        
        for river_id in river_ids_to_delete:
            river_ref = db.collection('rivers').document(river_id)
            
            # Delete all subcollection runs first
            runs = river_ref.collection('river_runs').stream()
            for run in runs:
                batch.delete(run.reference)
                batch_count += 1
                
                if batch_count >= 500:
                    batch.commit()
                    batch = db.batch()
                    batch_count = 0
            
            # Delete the river document
            batch.delete(river_ref)
            batch_count += 1
            
            if batch_count >= 500:
                batch.commit()
                batch = db.batch()
                batch_count = 0
        
        if batch_count > 0:
            batch.commit()
        
        print(f"   ✓ Deleted {len(river_ids_to_delete)} rivers and their subcollections")


def main():
    parser = argparse.ArgumentParser(
        description='Flatten data structure to top-level river_runs collection'
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
        '--delete-rivers',
        action='store_true',
        help='Delete rivers collection after migration (use with --migrate)'
    )
    
    args = parser.parse_args()
    
    # Initialize Firebase
    initialize_firebase()
    db = firestore.client()
    
    if args.dry_run:
        preview_migration(db)
    elif args.migrate:
        if args.delete_rivers:
            response = input("\n⚠️  WARNING: This will DELETE the entire rivers collection.\n"
                           "Are you sure? Type 'yes' to continue: ")
            if response.lower() != 'yes':
                print("Migration cancelled.")
                return
        
        apply_migration(db, delete_rivers=args.delete_rivers)
    else:
        print("Please specify --dry-run or --migrate")
        parser.print_help()


if __name__ == '__main__':
    main()
