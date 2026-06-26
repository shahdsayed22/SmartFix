// One-off: give technicians approximate coordinates (city centroid + jitter)
// so nearest-technician matching works. Only fills rows missing coords.
// Usage: node scripts/backfill-tech-coords.mjs "<mongoUri>"
import { MongoClient } from 'mongodb';

const URI = process.argv[2];
if (!URI) { console.error('usage: node backfill-tech-coords.mjs <uri>'); process.exit(1); }

const CENTROIDS = {
  Cairo: [30.0444, 31.2357], Giza: [30.0131, 31.2089], Alexandria: [31.2001, 29.9187],
  Luxor: [25.6872, 32.6396], Aswan: [24.0889, 32.8998], Mansoura: [31.0409, 31.3785],
  Tanta: [30.7865, 31.0004], 'Port Said': [31.2653, 32.3019], Suez: [29.9668, 32.5498],
  Ismailia: [30.5965, 32.2715], Faiyum: [29.3084, 30.8428], Zagazig: [30.5877, 31.502],
  Damietta: [31.4165, 31.8133], Minya: [28.1099, 30.7503], 'Beni Suef': [29.0661, 31.0994],
  Sohag: [26.5591, 31.6957], Hurghada: [27.2579, 33.8116], 'Sharm El Sheikh': [27.9158, 34.33],
  '6th of October': [29.9285, 30.9188], 'New Cairo': [30.03, 31.47],
};
const jitter = () => (Math.random() - 0.5) * 0.12; // ~±6 km

const client = new MongoClient(URI, { serverSelectionTimeoutMS: 20000 });
try {
  await client.connect();
  const col = client.db('smartfix').collection('technicians');
  const cursor = col.find({ $or: [{ latitude: { $in: [null, 0] } }, { latitude: { $exists: false } }] });
  const ops = [];
  let n = 0;
  for await (const t of cursor) {
    const [lat, lng] = CENTROIDS[t.city] || CENTROIDS.Cairo;
    ops.push({ updateOne: { filter: { _id: t._id }, update: { $set: { latitude: +(lat + jitter()).toFixed(5), longitude: +(lng + jitter()).toFixed(5) } } } });
    n++;
    if (ops.length >= 500) { await col.bulkWrite(ops); ops.length = 0; }
  }
  if (ops.length) await col.bulkWrite(ops);
  const withCoords = await col.countDocuments({ latitude: { $ne: 0 } });
  console.log(`backfilled ${n} technicians; total with coords now: ${withCoords}`);
} catch (e) {
  console.error('ERR', e.message);
  process.exitCode = 1;
} finally {
  await client.close();
}
