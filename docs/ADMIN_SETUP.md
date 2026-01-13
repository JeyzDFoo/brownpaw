# Setting Up Admin Custom Claims

## Overview

Firestore security rules now use Firebase custom claims for admin access instead of hardcoded UIDs. This is more secure and scalable.

## Setting Admin Claims via Firebase CLI

### Option 1: Using Firebase Functions (Recommended)

Create a Cloud Function to set admin claims:

```javascript
// functions/index.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

// HTTP function to set admin claim (protect this endpoint!)
exports.setAdminClaim = functions.https.onCall(async (data, context) => {
  // Only existing admins can create new admins
  if (context.auth.token.admin !== true) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can set admin claims'
    );
  }

  const uid = data.uid;
  
  try {
    await admin.auth().setCustomUserClaims(uid, { admin: true });
    return { message: `Admin claim set for user ${uid}` };
  } catch (error) {
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Bootstrapping function - REMOVE AFTER FIRST USE
exports.bootstrapFirstAdmin = functions.https.onRequest(async (req, res) => {
  // TODO: Add authentication check or remove after bootstrap
  const uid = req.query.uid;
  
  if (!uid) {
    res.status(400).send('Missing uid parameter');
    return;
  }

  try {
    await admin.auth().setCustomUserClaims(uid, { admin: true });
    res.send(`Admin claim set for user ${uid}. DELETE THIS FUNCTION NOW!`);
  } catch (error) {
    res.status(500).send(error.message);
  }
});
```

### Option 2: Using Firebase Admin SDK Script

Create a one-time script to set admin claims:

```javascript
// set-admin.js
const admin = require('firebase-admin');
const serviceAccount = require('./firebase-service-account.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

async function setAdminClaim(email) {
  try {
    const user = await admin.auth().getUserByEmail(email);
    await admin.auth().setCustomUserClaims(user.uid, { admin: true });
    console.log(`✅ Admin claim set for ${email} (${user.uid})`);
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

// Replace with your admin email
setAdminClaim('your-admin@example.com').then(() => process.exit());
```

Run it:
```bash
cd functions
npm install firebase-admin
node set-admin.js
```

### Option 3: Firebase Console (Manual)

Unfortunately, Firebase Console doesn't have a UI for custom claims. You must use one of the above methods.

## Verifying Admin Claims

Users need to sign out and sign back in for custom claims to take effect.

Check if your claim is set:

```dart
// In your Flutter app
final user = FirebaseAuth.instance.currentUser;
if (user != null) {
  final idTokenResult = await user.getIdTokenResult();
  final isAdmin = idTokenResult.claims?['admin'] == true;
  print('Is admin: $isAdmin');
}
```

## Security Notes

1. **Bootstrap carefully**: The first admin must be set via a secure script or Cloud Function
2. **Protect admin functions**: Never expose admin-setting functions publicly
3. **Audit trail**: Consider logging when admin claims are granted
4. **Revoke when needed**: Remove admin claims with `setCustomUserClaims(uid, { admin: false })`

## Migration from Hardcoded UIDs

Your previous hardcoded admin UIDs were:
- `08y0oUgfD2aWOgScPJRDdyfehsv2`
- `Ela2Ijh7kedHFLFMNGuKSaygWE02`

Run the script above for the email addresses associated with these UIDs to maintain admin access.
