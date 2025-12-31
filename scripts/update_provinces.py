"""
Update province/region field for all rivers based on source.

This script:
- Sets region to "BC" for rivers with source "bcwhitewater.org"
- Sets region to "AB" for all other rivers

Usage:
    python update_provinces.py --dry-run  # Preview changes
    python update_provinces.py --update   # Apply changes
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


def preview_updates(db):
    """Preview what changes will be made."""
    print("\n" + "="*60)
    print("PREVIEW (DRY RUN)")
    print("="*60 + "\n")
    
    rivers_ref = db.collection('rivers')
    docs = rivers_ref.stream()
    
    bc_count = 0
    ab_count = 0
    already_set = 0
    
    for doc in docs:
        data = doc.to_dict()
        river_name = data.get('name', doc.id)
        current_region = data.get('region', '')
        source = data.get('source', '')
        
        if source == 'bcwhitewater.org':
            new_region = 'BC'
            if current_region != new_region:
                print(f"   {river_name}: '{current_region}' → 'BC' (source: {source})")
                bc_count += 1
            else:
                already_set += 1
        else:
            new_region = 'AB'
            if current_region != new_region:
                print(f"   {river_name}: '{current_region}' → 'AB' (source: {source or 'none'})")
                ab_count += 1
            else:
                already_set += 1
    
    print(f"\n📊 Summary:")
    print(f"   Will update to BC: {bc_count}")
    print(f"   Will update to AB: {ab_count}")
    print(f"   Already correct: {already_set}")
    print(f"   Total: {bc_count + ab_count + already_set}")


def apply_updates(db):
    """Apply province updates to all rivers."""
    print("\n" + "="*60)
    print("APPLYING UPDATES")
    print("="*60 + "\n")
    
    rivers_ref = db.collection('rivers')
    docs = rivers_ref.stream()
    
    batch = db.batch()
    batch_count = 0
    bc_count = 0
    ab_count = 0
    skipped = 0
    
    for doc in docs:
        data = doc.to_dict()
        current_region = data.get('region', '')
        source = data.get('source', '')
        
        if source == 'bcwhitewater.org':
            new_region = 'BC'
            if current_region != new_region:
                batch.update(doc.reference, {'region': 'BC'})
                batch_count += 1
                bc_count += 1
            else:
                skipped += 1
        else:
            new_region = 'AB'
            if current_region != new_region:
                batch.update(doc.reference, {'region': 'AB'})
                batch_count += 1
                ab_count += 1
            else:
                skipped += 1
        
        # Commit batch every 500 operations
        if batch_count >= 500:
            batch.commit()
            print(f"   ✓ Committed batch of {batch_count} updates")
            batch = db.batch()
            batch_count = 0
    
    if batch_count > 0:
        batch.commit()
        print(f"   ✓ Committed final batch of {batch_count} updates")
    
    print(f"\n✅ Update complete!")
    print(f"   Updated to BC: {bc_count}")
    print(f"   Updated to AB: {ab_count}")
    print(f"   Skipped (already set): {skipped}")
    print(f"   Total processed: {bc_count + ab_count + skipped}")


def main():
    parser = argparse.ArgumentParser(
        description='Update province field for rivers based on source'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview changes without modifying data'
    )
    parser.add_argument(
        '--update',
        action='store_true',
        help='Apply the province updates'
    )
    
    args = parser.parse_args()
    
    # Initialize Firebase
    initialize_firebase()
    db = firestore.client()
    
    if args.dry_run:
        preview_updates(db)
    elif args.update:
        apply_updates(db)
    else:
        print("Please specify --dry-run or --update")
        parser.print_help()


if __name__ == '__main__':
    main()
