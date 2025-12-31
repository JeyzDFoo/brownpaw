import firebase_admin
from firebase_admin import credentials, firestore
import json

# Initialize Firebase
try:
    firebase_admin.get_app()
except ValueError:
    cred = credentials.Certificate('../../firebase-service-account.json')
    firebase_admin.initialize_app(cred)

db = firestore.client()

# Query for Adam River
print('=== Querying for Adam River ===')
adam_runs = list(db.collection('river_runs')
                .where('name', '==', 'Adam River')
                .stream())

print(f'Found {len(adam_runs)} run(s) for Adam River\n')

# Display the data
for doc in adam_runs:
    data = doc.to_dict()
    print(f'Document ID: {doc.id}')
    print(json.dumps(data, indent=2, default=str))
    print('\n' + '='*80 + '\n')
