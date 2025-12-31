import firebase_admin
from firebase_admin import credentials, firestore

# Initialize Firebase
try:
    firebase_admin.get_app()
except ValueError:
    cred = credentials.Certificate('firebase-service-account.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

def delete_collection(collection_name, batch_size=100):
    """Delete all documents in a collection"""
    print(f'Starting deletion of collection: {collection_name}')
    
    collection_ref = db.collection(collection_name)
    deleted = 0
    
    while True:
        # Get a batch of documents
        docs = list(collection_ref.limit(batch_size).stream())
        
        if not docs:
            break
        
        # Delete documents in batch
        batch = db.batch()
        for doc in docs:
            print(f'Deleting: {doc.id}')
            batch.delete(doc.reference)
            deleted += 1
        
        batch.commit()
        print(f'Deleted {len(docs)} documents...')
    
    print(f'\nTotal documents deleted: {deleted}')
    return deleted

if __name__ == '__main__':
    # Confirm deletion
    response = input('Are you sure you want to delete ALL river_runs? (yes/no): ')
    
    if response.lower() == 'yes':
        count = delete_collection('river_runs')
        print(f'\n✓ Successfully deleted {count} river runs')
        print('Collection is now empty and ready for fresh data')
    else:
        print('Deletion cancelled')
