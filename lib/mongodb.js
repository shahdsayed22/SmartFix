import mongoose from 'mongoose';

let cached = global.mongoose;

if (!cached) {
    cached = global.mongoose = { conn: null, promise: null };
}

async function dbConnect() {
    if (cached.conn) {
        return cached.conn;
    }

    // Read + validate the URI at connection time (NOT at module import), so
    // `next build` page-data collection doesn't fail when the env var isn't
    // present at build time. The error only surfaces on an actual DB request.
    const MONGODB_URI = process.env.MONGODB_URI;
    if (!MONGODB_URI) {
        throw new Error('Please define the MONGODB_URI environment variable');
    }

    if (!cached.promise) {
        const opts = {
            bufferCommands: false,
            // Fail fast when the DB is unreachable instead of hanging ~30s on
            // the driver default. Keeps API routes from blocking the dashboard.
            serverSelectionTimeoutMS: 5000,
            connectTimeoutMS: 5000,
            socketTimeoutMS: 20000,
        };

        cached.promise = mongoose.connect(MONGODB_URI, opts).then((mongoose) => {
            return mongoose;
        });
    }

    try {
        cached.conn = await cached.promise;
    } catch (e) {
        cached.promise = null;
        throw e;
    }

    return cached.conn;
}

export default dbConnect;
