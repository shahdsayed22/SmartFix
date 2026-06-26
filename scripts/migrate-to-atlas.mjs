// One-off: copy the local `smartfix` DB to a target (Atlas) cluster.
// Usage: node scripts/migrate-to-atlas.mjs <sourceUri> <destUri>
import { MongoClient } from 'mongodb';

const SRC = process.argv[2];
const DST = process.argv[3];
const DB = 'smartfix';

if (!SRC || !DST) {
  console.error('usage: node migrate-to-atlas.mjs <sourceUri> <destUri>');
  process.exit(1);
}

const src = new MongoClient(SRC, { serverSelectionTimeoutMS: 15000 });
const dst = new MongoClient(DST, { serverSelectionTimeoutMS: 20000 });

try {
  await src.connect();
  console.log('connected: source (local)');
  await dst.connect();
  console.log('connected: destination (Atlas)');

  const sdb = src.db(DB);
  const ddb = dst.db(DB);
  const cols = (await sdb.listCollections().toArray()).filter((c) => c.type === 'collection');

  let totalDocs = 0;
  for (const c of cols) {
    const name = c.name;
    const docs = await sdb.collection(name).find({}).toArray();
    if (docs.length) {
      await ddb.collection(name).deleteMany({}); // clean dest collection first
      const BATCH = 1000;
      for (let i = 0; i < docs.length; i += BATCH) {
        await ddb.collection(name).insertMany(docs.slice(i, i + BATCH), { ordered: false });
      }
    }
    totalDocs += docs.length;
    console.log(`  ${name.padEnd(20)} ${docs.length} docs -> migrated`);
  }

  console.log('--- destination counts ---');
  for (const c of cols) {
    const n = await ddb.collection(c.name).countDocuments();
    console.log(`  ${c.name.padEnd(20)} ${n}`);
  }
  console.log(`DONE: ${cols.length} collections, ${totalDocs} docs migrated`);
} catch (e) {
  console.error('MIGRATION ERROR:', e.message);
  process.exitCode = 1;
} finally {
  await src.close().catch(() => {});
  await dst.close().catch(() => {});
}
