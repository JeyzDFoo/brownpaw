#!/usr/bin/env python3
"""
Update existing BC Whitewater documents in Firestore to match the new schema.
- Change 'region' field to 'province' ('BC')
- Rename 'bcRegion' field to 'region' (BC-specific regional info)
"""

import os
import firebase_admin
from firebase_admin import credentials, firestore

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

def update_bc_runs_schema():
    """Update existing BC runs to match new schema."""
    print("Updating BC runs schema...")
    
    # Get all current BC runs
    bc_runs = list(db.collection('river_runs').where('region', '==', 'BC').stream())
    print(f"Found {len(bc_runs)} BC runs to update")
    
    updated_count = 0
    error_count = 0
    
    for doc in bc_runs:
        try:
            data = doc.to_dict()
            updates = {}
            
            # Change 'region' to 'province' if it's 'BC'
            if data.get('region') == 'BC':
                updates['province'] = 'BC'
                # Remove the old 'region' field
                updates['region'] = firestore.DELETE_FIELD
            
            # If there's a 'bcRegion' field, rename it to 'region'
            if 'bcRegion' in data:
                updates['region'] = data['bcRegion']
                updates['bcRegion'] = firestore.DELETE_FIELD
            
            # Add province field if missing (shouldn't happen, but just in case)
            if 'province' not in data and 'province' not in updates:
                updates['province'] = 'BC'
            
            # Update timestamp
            updates['updatedAt'] = firestore.SERVER_TIMESTAMP
            
            if updates:
                # Apply updates
                doc.reference.update(updates)
                print(f"✓ Updated {doc.id}")
                updated_count += 1
            else:
                print(f"- No updates needed for {doc.id}")
                
        except Exception as e:
            print(f"✗ Error updating {doc.id}: {e}")
            error_count += 1
    
    print(f"\nUpdate complete!")
    print(f"  Updated: {updated_count}")
    print(f"  Errors: {error_count}")
    print(f"  Total: {len(bc_runs)}")

if __name__ == '__main__':
    update_bc_runs_schema()