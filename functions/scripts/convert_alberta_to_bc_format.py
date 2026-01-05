"""
Convert Alberta runs to use BC format (difficultyClass only).

This removes difficultyMin and difficultyMax fields from Alberta runs,
keeping only the difficultyClass string field.

Usage:
    python convert_alberta_to_bc_format.py --dry-run  # Preview changes
    python convert_alberta_to_bc_format.py --update   # Apply changes
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
    
    runs_ref = db.collection('river_runs').where('region', '==', 'AB')
    docs = runs_ref.stream()
    
    to_update = []
    already_correct = []
    
    for doc in docs:
        data = doc.to_dict()
        run_name = data.get('name', doc.id)
        has_min = 'difficultyMin' in data
        has_max = 'difficultyMax' in data
        difficulty_class = data.get('difficultyClass', 'N/A')
        
        if has_min or has_max:
            to_update.append({
                'id': doc.id,
                'name': run_name,
                'difficultyClass': difficulty_class,
                'difficultyMin': data.get('difficultyMin'),
                'difficultyMax': data.get('difficultyMax')
            })
            print(f"   {run_name}")
            print(f"      Will remove: difficultyMin={data.get('difficultyMin')}, difficultyMax={data.get('difficultyMax')}")
            print(f"      Will keep: difficultyClass='{difficulty_class}'")
            print()
        else:
            already_correct.append(run_name)
    
    print(f"\n📊 Summary:")
    print(f"   Runs to update: {len(to_update)}")
    print(f"   Already correct: {len(already_correct)}")
    print(f"   Total: {len(to_update) + len(already_correct)}")


def apply_updates(db):
    """Remove difficultyMin/Max fields from Alberta runs."""
    print("\n" + "="*60)
    print("APPLYING UPDATES")
    print("="*60 + "\n")
    
    runs_ref = db.collection('river_runs').where('region', '==', 'AB')
    docs = runs_ref.stream()
    
    batch = db.batch()
    batch_count = 0
    updated_count = 0
    skipped = 0
    
    for doc in docs:
        data = doc.to_dict()
        has_min = 'difficultyMin' in data
        has_max = 'difficultyMax' in data
        
        if has_min or has_max:
            # Remove the fields
            updates = {}
            if has_min:
                updates['difficultyMin'] = firestore.DELETE_FIELD
            if has_max:
                updates['difficultyMax'] = firestore.DELETE_FIELD
            
            batch.update(doc.reference, updates)
            batch_count += 1
            updated_count += 1
            
            run_name = data.get('name', doc.id)
            print(f"   ✓ {run_name}")
        else:
            skipped += 1
        
        # Commit batch every 500 operations
        if batch_count >= 500:
            batch.commit()
            print(f"\n   Committed batch of {batch_count} updates\n")
            batch = db.batch()
            batch_count = 0
    
    if batch_count > 0:
        batch.commit()
        print(f"\n   Committed final batch of {batch_count} updates")
    
    print(f"\n✅ Update complete!")
    print(f"   Updated: {updated_count} runs")
    print(f"   Skipped (already correct): {skipped}")
    print(f"   Total processed: {updated_count + skipped}")


def main():
    parser = argparse.ArgumentParser(
        description='Convert Alberta runs to BC format (difficultyClass only)'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview changes without modifying data'
    )
    parser.add_argument(
        '--update',
        action='store_true',
        help='Apply the updates'
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
