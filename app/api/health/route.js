import { NextResponse } from 'next/server';
import mongoose from 'mongoose';
import dbConnect from '@/lib/mongodb';
import Issue from '@/models/Issue';
import User from '@/models/User';
import Technician from '@/models/Technician';

const READY_STATE = {
    0: 'disconnected',
    1: 'connected',
    2: 'connecting',
    3: 'disconnecting',
};

export async function GET() {
    const now = new Date();

    // --- Process / runtime metrics (always measurable) ---
    const uptimeSeconds = Math.round(process.uptime());
    const mem = process.memoryUsage();
    const memUsedMB = Math.round(mem.rss / 1024 / 1024);
    const heapUsedMB = Math.round(mem.heapUsed / 1024 / 1024);
    const heapTotalMB = Math.round(mem.heapTotal / 1024 / 1024);
    const heapPct = heapTotalMB > 0 ? Math.round((heapUsedMB / heapTotalMB) * 100) : 0;

    // --- Database connectivity / state + latency (real) ---
    let dbStatus = 'down';
    let dbReadyState = 0;
    let dbReadyLabel = READY_STATE[0];
    let dbPingMs = null;
    let dbError = null;

    try {
        await dbConnect();
        dbReadyState = mongoose.connection.readyState;
        dbReadyLabel = READY_STATE[dbReadyState] || 'unknown';

        if (dbReadyState === 1 && mongoose.connection.db) {
            const start = Date.now();
            await mongoose.connection.db.admin().command({ ping: 1 });
            dbPingMs = Date.now() - start;
            dbStatus = 'healthy';
        } else if (dbReadyState === 2) {
            dbStatus = 'degraded';
        } else {
            dbStatus = 'down';
        }
    } catch (e) {
        dbStatus = 'down';
        dbError = e.message;
    }

    // --- Live document counts (real, only when connected) ---
    let issuesCount = null;
    let usersCount = null;
    let techniciansCount = null;
    let documentsTotal = null;

    if (dbStatus === 'healthy') {
        try {
            const [issues, users, technicians] = await Promise.all([
                Issue.countDocuments(),
                User.countDocuments(),
                Technician.countDocuments(),
            ]);
            issuesCount = issues;
            usersCount = users;
            techniciansCount = technicians;
            documentsTotal = issues + users + technicians;
        } catch (e) {
            dbError = dbError || e.message;
        }
    }

    const apiStatus = 'healthy'; // if this handler runs, the API gateway is up

    const payload = {
        timestamp: now.toISOString(),
        lastChecked: now.toISOString(),
        api: {
            status: apiStatus,
            uptimeSeconds,
            memory: {
                rssMB: memUsedMB,
                heapUsedMB,
                heapTotalMB,
                heapPct,
            },
            nodeVersion: process.version,
        },
        database: {
            status: dbStatus,
            readyState: dbReadyState,
            readyLabel: dbReadyLabel,
            pingMs: dbPingMs,
            error: dbError,
            counts: {
                issues: issuesCount,
                users: usersCount,
                technicians: techniciansCount,
                total: documentsTotal,
            },
        },
        // Genuinely unmeasurable in this environment — reported as null (N/A) rather than faked.
        llm: {
            status: 'unknown',
            model: null,
            tokenUsage24h: null,
            tokenLimit: null,
            inferenceLatencyMs: null,
            queueLength: null,
            classificationsPerMinute: null,
        },
    };

    return NextResponse.json(payload);
}
