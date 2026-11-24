// Firestore security rules tests. Run with `npm test` from this folder
// (needs Java for the Firestore emulator).
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  deleteDoc,
  doc,
  getDoc,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-brownpaw',
    firestore: { rules: readFileSync('../../firestore.rules', 'utf8') },
  });
});

after(async () => {
  await env.cleanup();
});

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await setDoc(doc(db, 'users/alice'), { email: 'a@example.com' });
    await setDoc(doc(db, 'river_runs/curated'), {
      name: 'Curated', verified: true, createdBy: 'admin',
    });
    await setDoc(doc(db, 'river_runs/alice-run'), {
      name: 'Alice run', verified: false, visibility: 'private',
      createdBy: 'alice',
    });
  });
});

const alice = () => env.authenticatedContext('alice').firestore();
const bob = () => env.authenticatedContext('bob').firestore();

describe('users', () => {
  test('owner can delete their profile', async () => {
    await assertSucceeds(deleteDoc(doc(alice(), 'users/alice')));
  });

  test('others cannot delete a profile', async () => {
    await assertFails(deleteDoc(doc(bob(), 'users/alice')));
  });
});

describe('river_runs', () => {
  const privateRun = (uid) => ({
    name: 'New run', river: 'New run', createdBy: uid, verified: false,
    visibility: 'private', createdAt: serverTimestamp(),
  });

  test('paddler can add a private unverified run', async () => {
    await assertSucceeds(
      setDoc(doc(alice(), 'river_runs/new-run'), privateRun('alice')),
    );
  });

  test('paddler cannot add a verified run', async () => {
    await assertFails(setDoc(doc(alice(), 'river_runs/new-run'), {
      ...privateRun('alice'), verified: true,
    }));
  });

  test('paddler cannot add a run on behalf of someone else', async () => {
    await assertFails(
      setDoc(doc(alice(), 'river_runs/new-run'), privateRun('bob')),
    );
  });

  test('paddler cannot overwrite a curated run', async () => {
    await assertFails(
      setDoc(doc(alice(), 'river_runs/curated'), privateRun('alice')),
    );
  });

  test('paddler can edit and delete their own private run', async () => {
    await assertSucceeds(
      updateDoc(doc(alice(), 'river_runs/alice-run'), { name: 'Renamed' }),
    );
    await assertSucceeds(deleteDoc(doc(alice(), 'river_runs/alice-run')));
  });

  test('paddler cannot verify their own run', async () => {
    await assertFails(
      updateDoc(doc(alice(), 'river_runs/alice-run'), { verified: true }),
    );
  });

  test('others cannot edit or delete a private run', async () => {
    await assertFails(
      updateDoc(doc(bob(), 'river_runs/alice-run'), { name: 'Mine now' }),
    );
    await assertFails(deleteDoc(doc(bob(), 'river_runs/alice-run')));
  });

  test('signed-in paddlers can read runs', async () => {
    await assertSucceeds(getDoc(doc(bob(), 'river_runs/curated')));
  });
});
