"""
Validate and normalize all river_runs to match the RiverRun model format.

This script:
1. Checks all river_runs documents for consistency
2. Converts field names to camelCase (Firestore format)
3. Ensures required fields are present
4. Reports any issues or missing data

Usage:
    python validate_river_runs.py --dry-run   # Preview changes
    python validate_river_runs.py --fix       # Apply fixes
"""

import argparse
import firebase_admin
from firebase_admin import credentials, firestore
from typing import Dict, Any, List, Tuple
from models import RiverRun


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


# Field mapping from various formats to correct camelCase
FIELD_MAPPINGS = {
    'river_id': 'riverId',
    'difficulty_class': 'difficultyClass',
    'difficulty_min': 'difficultyMin',
    'difficulty_max': 'difficultyMax',
    'estimated_time': 'estimatedTime',
    'flow_unit': 'flowUnit',
    'station_id': 'stationId',
    'flow_ranges': 'flowRanges',
    'source_url': 'sourceUrl',
    'created_by': 'createdBy',
    'created_at': 'createdAt',
    'updated_at': 'updatedAt',
}

# Required fields for a river run
REQUIRED_FIELDS = ['name', 'river', 'region', 'riverId', 'difficultyClass']


def normalize_document(doc_id: str, data: Dict[str, Any]) -> Tuple[Dict[str, Any], List[str]]:
    """
    Normalize a document to match RiverRun model format.
    
    Args:
        doc_id: The Firestore document ID
        data: The document data
    
    Returns:
        Tuple of (normalized_data, list_of_changes)
    """
    normalized = {}
    changes = []
    
    # Apply field name mappings
    for old_key, new_key in FIELD_MAPPINGS.items():
        if old_key in data:
            normalized[new_key] = data[old_key]
            changes.append(f"Renamed {old_key} → {new_key}")
            # Don't copy the old key
            data = {k: v for k, v in data.items() if k != old_key}
    
    # Copy all other fields as-is
    for key, value in data.items():
        if key not in normalized:
            normalized[key] = value
    
    # Ensure riverId matches document ID
    if 'riverId' not in normalized or normalized.get('riverId') != doc_id:
        old_river_id = normalized.get('riverId', 'missing')
        normalized['riverId'] = doc_id
        if old_river_id != doc_id and old_river_id != 'missing':
            changes.append(f"Fixed riverId: {old_river_id} → {doc_id}")
        elif old_river_id == 'missing':
            changes.append(f"Added riverId: {doc_id}")
    
    return normalized, changes


def validate_document(doc_id: str, data: Dict[str, Any]) -> List[str]:
    """
    Validate a document and return list of issues.
    """
    issues = []
    
    # Check required fields
    for field in REQUIRED_FIELDS:
        if field not in data or data[field] is None or data[field] == '':
            issues.append(f"Missing required field: {field}")
    
    # Check if document ID matches riverId
    if 'riverId' in data and data['riverId'] != doc_id:
        issues.append(f"Document ID '{doc_id}' doesn't match riverId '{data['riverId']}'")
    
    # Check for old snake_case fields
    for old_field in FIELD_MAPPINGS.keys():
        if old_field in data:
            issues.append(f"Has snake_case field: {old_field}")
    
    return issues


def analyze_runs(db):
    """Analyze all river_runs and report status."""
    print("\n" + "="*70)
    print("ANALYZING RIVER_RUNS COLLECTION")
    print("="*70 + "\n")
    
    runs_ref = db.collection('river_runs')
    docs = list(runs_ref.stream())
    
    total = len(docs)
    needs_normalization = []
    has_issues = []
    perfect = []
    
    print(f"📊 Found {total} river runs\n")
    
    for doc in docs:
        data = doc.to_dict()
        doc_id = doc.id
        
        # Normalize and check for changes
        normalized, changes = normalize_document(doc_id, data.copy())
        issues = validate_document(doc_id, normalized)
        
        if changes or issues:
            needs_normalization.append({
                'id': doc_id,
                'name': data.get('name', doc_id),
                'changes': changes,
                'issues': issues,
                'region': data.get('region', 'unknown')
            })
        else:
            perfect.append(doc_id)
    
    # Group by region
    by_region = {}
    for run in needs_normalization:
        region = run['region']
        if region not in by_region:
            by_region[region] = []
        by_region[region].append(run)
    
    # Print summary by region
    for region in sorted(by_region.keys()):
        runs = by_region[region]
        print(f"\n{region} Region: {len(runs)} runs need attention")
        print("-" * 70)
        
        for run in runs[:5]:  # Show first 5 per region
            print(f"\n   {run['name']} ({run['id']})")
            if run['changes']:
                for change in run['changes']:
                    print(f"      • {change}")
            if run['issues']:
                for issue in run['issues']:
                    print(f"      ⚠️  {issue}")
        
        if len(runs) > 5:
            print(f"\n   ... and {len(runs) - 5} more")
    
    print(f"\n{'='*70}")
    print(f"📊 SUMMARY")
    print(f"{'='*70}")
    print(f"   Total runs: {total}")
    print(f"   Perfect (no changes needed): {len(perfect)}")
    print(f"   Need normalization: {len(needs_normalization)}")
    
    return needs_normalization


def fix_runs(db, dry_run=True):
    """Fix and normalize all river_runs."""
    print("\n" + "="*70)
    print("FIXING RIVER_RUNS" if not dry_run else "DRY RUN - PREVIEW FIXES")
    print("="*70 + "\n")
    
    runs_ref = db.collection('river_runs')
    docs = list(runs_ref.stream())
    
    batch = db.batch()
    batch_count = 0
    updated_count = 0
    
    for doc in docs:
        data = doc.to_dict()
        doc_id = doc.id
        
        # Normalize
        normalized, changes = normalize_document(doc_id, data.copy())
        
        if changes:
            if dry_run:
                print(f"   Would update: {normalized.get('name', doc_id)}")
                for change in changes:
                    print(f"      • {change}")
            else:
                # Delete old snake_case fields and update with normalized data
                updates = {}
                
                # Add all normalized fields
                for key, value in normalized.items():
                    updates[key] = value
                
                # Mark old snake_case fields for deletion
                for old_field in FIELD_MAPPINGS.keys():
                    if old_field in data:
                        updates[old_field] = firestore.DELETE_FIELD
                
                batch.update(doc.reference, updates)
                batch_count += 1
                updated_count += 1
                
                print(f"   ✓ Updated: {normalized.get('name', doc_id)}")
                
                # Commit batch every 500 operations
                if batch_count >= 500:
                    batch.commit()
                    print(f"\n   Committed batch of {batch_count} updates\n")
                    batch = db.batch()
                    batch_count = 0
    
    if not dry_run and batch_count > 0:
        batch.commit()
        print(f"\n   Committed final batch of {batch_count} updates")
    
    if dry_run:
        print(f"\n📋 Would update {updated_count} runs")
    else:
        print(f"\n✅ Successfully updated {updated_count} runs")


def main():
    parser = argparse.ArgumentParser(
        description='Validate and normalize river_runs collection'
    )
    parser.add_argument(
        '--dry-run',
        action='store_true',
        help='Preview changes without modifying data'
    )
    parser.add_argument(
        '--fix',
        action='store_true',
        help='Apply fixes to normalize all runs'
    )
    parser.add_argument(
        '--analyze',
        action='store_true',
        help='Analyze and report on run status'
    )
    
    args = parser.parse_args()
    
    # Initialize Firebase
    initialize_firebase()
    db = firestore.client()
    
    if args.analyze:
        analyze_runs(db)
    elif args.dry_run:
        fix_runs(db, dry_run=True)
    elif args.fix:
        response = input("\n⚠️  This will modify the database. Continue? (yes/no): ")
        if response.lower() == 'yes':
            fix_runs(db, dry_run=False)
        else:
            print("Cancelled.")
    else:
        print("Please specify --analyze, --dry-run, or --fix")
        parser.print_help()


if __name__ == '__main__':
    main()
