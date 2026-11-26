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
  collection,
  deleteDoc,
  getDocs,
  query,
  where,
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
      name: 'Curated', verified: true, visibility: 'public',
      createdBy: 'admin',
    });
    await setDoc(doc(db, 'river_runs/old-curated'), {
      name: 'Old curated, no visibility field yet',
    });
    await setDoc(doc(db, 'descents/alice-public'), {
      userId: 'alice', runId: 'curated', isPublic: true,
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

  test('signed-in paddlers can read curated runs', async () => {
    await assertSucceeds(getDoc(doc(bob(), 'river_runs/curated')));
  });

  test('a run without visibility needs the backfill first', async () => {
    await assertFails(getDoc(doc(bob(), 'river_runs/old-curated')));
  });

  test('others cannot read a private run', async () => {
    await assertFails(getDoc(doc(bob(), 'river_runs/alice-run')));
    await assertSucceeds(getDoc(doc(alice(), 'river_runs/alice-run')));
  });

  test('the app\'s two run queries are allowed', async () => {
    await assertSucceeds(getDocs(query(
      collection(bob(), 'river_runs'), where('visibility', '==', 'public'),
    )));
    await assertSucceeds(getDocs(query(
      collection(alice(), 'river_runs'), where('createdBy', '==', 'alice'),
    )));
  });

  test('reading the whole collection is denied', async () => {
    await assertFails(getDocs(collection(bob(), 'river_runs')));
  });
});

describe('descents', () => {
  test('a public descent is still private to its paddler', async () => {
    await assertFails(getDoc(doc(bob(), 'descents/alice-public')));
    await assertSucceeds(getDoc(doc(alice(), 'descents/alice-public')));
  });
});

describe('flow_alerts', () => {
  const alert = (uid, extra = {}) => ({
    userId: uid, runId: 'tamihi', runName: 'Tamihi to Vedder',
    stationId: 'environment_canada_08MH001', minFlow: 20, maxFlow: 40,
    word: 'good', createdAt: serverTimestamp(), ...extra,
  });

  test('paddler can add, list and remove their own alert', async () => {
    const ref = doc(alice(), 'flow_alerts/alice_tamihi');
    await assertSucceeds(setDoc(ref, alert('alice')));
    await assertSucceeds(getDocs(query(
      collection(alice(), 'flow_alerts'), where('userId', '==', 'alice'),
    )));
    await assertSucceeds(deleteDoc(ref));
  });

  test('paddler cannot add an alert for someone else', async () => {
    await assertFails(
      setDoc(doc(bob(), 'flow_alerts/alice_tamihi'), alert('alice')),
    );
    await assertFails(
      setDoc(doc(bob(), 'flow_alerts/alice_tamihi'), alert('bob')),
    );
  });

  test('paddler cannot set the server bookkeeping fields', async () => {
    await assertFails(setDoc(
      doc(alice(), 'flow_alerts/alice_tamihi'),
      alert('alice', { inRange: true }),
    ));
  });

  test('a range must run low to high', async () => {
    await assertFails(setDoc(
      doc(alice(), 'flow_alerts/alice_tamihi'),
      alert('alice', { minFlow: 40, maxFlow: 20 }),
    ));
  });

  test('others cannot read or delete an alert', async () => {
    await env.withSecurityRulesDisabled((ctx) =>
      setDoc(doc(ctx.firestore(), 'flow_alerts/alice_tamihi'), alert('alice')),
    );
    await assertFails(getDoc(doc(bob(), 'flow_alerts/alice_tamihi')));
    await assertFails(deleteDoc(doc(bob(), 'flow_alerts/alice_tamihi')));
  });
});

// Signing in to an existing account after using the app without one: the
// anonymous data is read as the anonymous user, then copied in as the
// account (lib/data/account_merge.dart).
describe('bringing anonymous data into an existing account', () => {
  const anon = () => env.authenticatedContext('anon').firestore();
  const when = new Date('2026-05-03T17:00:00Z');

  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const db = ctx.firestore();
      await setDoc(doc(db, 'users/anon'), { email: null, favorites: ['curated'] });
      await setDoc(doc(db, 'descents/anon-1'), {
        userId: 'anon', runId: 'anon-run', runName: 'Anon run',
        date: when, createdAt: when, isPublic: false,
      });
      await setDoc(doc(db, 'river_runs/anon-run'), {
        riverId: 'anon-run', name: 'Anon run', river: 'Creek',
        verified: false, visibility: 'private', createdBy: 'anon',
      });
      await setDoc(doc(db, 'flow_alerts/anon_curated'), {
        userId: 'anon', runId: 'curated', stationId: 's',
        minFlow: 1, maxFlow: 2, inRange: true,
      });
    });
  });

  test('the anonymous user can read everything to carry over', async () => {
    const db = anon();
    await assertSucceeds(getDoc(doc(db, 'users/anon')));
    await assertSucceeds(getDocs(query(collection(db, 'descents'), where('userId', '==', 'anon'))));
    await assertSucceeds(getDocs(query(collection(db, 'river_runs'), where('createdBy', '==', 'anon'))));
    await assertSucceeds(getDocs(query(collection(db, 'flow_alerts'), where('userId', '==', 'anon'))));
  });

  test('the account can write the copies', async () => {
    const db = alice();
    await assertSucceeds(setDoc(doc(db, 'river_runs/anon-run-alice'), {
      riverId: 'anon-run-alice', name: 'Anon run', river: 'Creek',
      verified: false, visibility: 'private', createdBy: 'alice',
      mergedFrom: 'anon/anon-run',
    }));
    await assertSucceeds(setDoc(doc(db, 'descents/copy-1'), {
      userId: 'alice', runId: 'anon-run-alice', runName: 'Anon run',
      date: when, createdAt: when, isPublic: false, mergedFrom: 'anon/anon-1',
    }));
    await assertSucceeds(setDoc(doc(db, 'flow_alerts/alice_curated'), {
      userId: 'alice', runId: 'curated', stationId: 's',
      minFlow: 1, maxFlow: 2,
    }));
    await assertSucceeds(setDoc(doc(db, 'users/alice'), {
      favorites: ['curated'],
    }, { merge: true }));
  });

  test('the account still cannot touch the anonymous originals', async () => {
    const db = alice();
    await assertFails(getDoc(doc(db, 'descents/anon-1')));
    await assertFails(getDoc(doc(db, 'users/anon')));
    await assertFails(updateDoc(doc(db, 'river_runs/anon-run'), { createdBy: 'alice' }));
  });
});
