/**
 * Delete demo / test accounts from Firebase Auth + their Firestore `users`
 * docs, so emails can be registered fresh. Firebase Auth is the store that
 * makes "email already in use" appear — wiping MongoDB does NOT clear it.
 *
 * SETUP (one time):
 *   1. Firebase console → Project settings → Service accounts →
 *      "Generate new private key" → save the JSON as:
 *        SmartFix/serviceAccountKey.json   (already gitignored below)
 *   2. npm i -D firebase-admin
 *
 * Usage:
 *   node scripts/wipe-firebase.mjs --dry                 # list demo users, delete nothing
 *   node scripts/wipe-firebase.mjs --emails a@x.com,b@y.com   # delete just these
 *   node scripts/wipe-firebase.mjs --all                 # delete ALL auth users (fresh slate)
 */
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const admin = require('firebase-admin');

const args = process.argv.slice(2);
const DRY = args.includes('--dry');
const ALL = args.includes('--all');
const emailArg = args.find((a) => a.startsWith('--emails'));
const onlyEmails = emailArg
  ? emailArg.split('=')[1]?.split(',').map((s) => s.trim().toLowerCase()).filter(Boolean)
  : null;

const keyPath = new URL('../serviceAccountKey.json', import.meta.url);
const serviceAccount = JSON.parse(readFileSync(keyPath, 'utf8'));
admin.initializeApp({ credential: admin.credential.cert(serviceAccount) });

const auth = admin.auth();
const db = admin.firestore();

// Collect targets, paging through all users.
const targets = [];
let pageToken;
do {
  const res = await auth.listUsers(1000, pageToken);
  for (const u of res.users) {
    const email = (u.email || '').toLowerCase();
    if (ALL || (onlyEmails && onlyEmails.includes(email))) {
      targets.push({ uid: u.uid, email: u.email || '(no email)' });
    }
  }
  pageToken = res.pageToken;
} while (pageToken);

console.log(`\n${DRY ? '🔎 DRY RUN' : '⚠️  DELETING'} — ${targets.length} account(s):`);
targets.forEach((t) => console.log(`   ${t.uid}  ${t.email}`));

if (!DRY) {
  for (const t of targets) {
    await auth.deleteUser(t.uid).catch((e) => console.warn(`   auth ${t.uid}: ${e.message}`));
    await db.collection('users').doc(t.uid).delete().catch(() => {});
  }
  console.log(`\n✅ Deleted ${targets.length} account(s) from Auth + Firestore.`);
} else {
  console.log('\n(dry run — nothing deleted)');
}
process.exit(0);
