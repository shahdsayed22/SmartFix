/**
 * Wipe demo / test data from the SmartFix MongoDB so you can begin fresh
 * role-testing. Empties every app collection EXCEPT configuration that the
 * app needs to function out of the box (commission settings + service
 * categories).
 *
 * Usage:
 *   node --env-file=.env.local scripts/wipe-demo.mjs --dry   # show what WOULD go
 *   node --env-file=.env.local scripts/wipe-demo.mjs         # actually wipe
 *
 * NOTE: This only touches MongoDB. Firebase Auth accounts (used for login)
 * are NOT in Mongo — clear those separately (Firebase console or
 * scripts/wipe-firebase.mjs).
 */
import { MongoClient } from 'mongodb';

const DRY = process.argv.includes('--dry');

// Collections to PRESERVE (lowercased). Everything else gets emptied.
const KEEP = new Set(['commissionsettings', 'servicecategories']);

const uri = process.env.MONGODB_URI;
if (!uri) {
  console.error('✖ MONGODB_URI not set. Run with: node --env-file=.env.local scripts/wipe-demo.mjs');
  process.exit(1);
}

const client = new MongoClient(uri);
try {
  await client.connect();
  const db = client.db(); // database name comes from the connection string
  const cols = (await db.listCollections().toArray())
    .map((c) => c.name)
    .filter((n) => !n.startsWith('system.'))
    .sort();

  console.log(`\n${DRY ? '🔎 DRY RUN' : '⚠️  WIPING'} — database "${db.databaseName}", ${cols.length} collections\n`);

  let deleted = 0;
  for (const name of cols) {
    const count = await db.collection(name).countDocuments();
    if (KEEP.has(name.toLowerCase())) {
      console.log(`  ✔ KEEP  ${name.padEnd(22)} (${count} docs)`);
      continue;
    }
    if (DRY) {
      console.log(`  ✗ WIPE  ${name.padEnd(22)} (${count} docs would be deleted)`);
      deleted += count;
    } else {
      const res = await db.collection(name).deleteMany({});
      console.log(`  ✗ WIPE  ${name.padEnd(22)} (deleted ${res.deletedCount}/${count})`);
      deleted += res.deletedCount;
    }
  }

  console.log(`\n${DRY ? 'Would delete' : 'Deleted'} ${deleted} documents. Kept: ${[...KEEP].join(', ')}\n`);
} finally {
  await client.close();
}
