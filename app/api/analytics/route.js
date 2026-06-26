import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Technician from '@/models/Technician';
import Issue from '@/models/Issue';
import User from '@/models/User';

export async function GET() {
    try {
        await dbConnect();

        const [
            totalTechnicians,
            verifiedCount,
            categoryBreakdown,
            cityDistribution,
            ratingDistribution,
            avgRating,
            totalIssuesResolved,
            topTechnicians,
            monthlyGrowth,
            userMonthlyGrowth,
            // Issue stats
            totalIssues,
            issuesByStatus,
            issuesByCategory,
            issuesByUrgency,
            // User stats
            totalUsers,
            usersByRole,
            verifiedUsers,
        ] = await Promise.all([
            Technician.countDocuments(),
            Technician.countDocuments({ isVerified: true }),
            Technician.aggregate([
                { $group: { _id: '$category', count: { $sum: 1 }, avgRating: { $avg: '$rating' } } },
            ]),
            Technician.aggregate([
                { $group: { _id: '$city', count: { $sum: 1 } } },
                { $sort: { count: -1 } },
                { $limit: 10 },
            ]),
            Technician.aggregate([
                {
                    $bucket: {
                        groupBy: '$rating',
                        boundaries: [0, 1, 2, 3, 4, 5, 5.1],
                        default: 'Other',
                        output: { count: { $sum: 1 } },
                    },
                },
            ]),
            Technician.aggregate([{ $group: { _id: null, avg: { $avg: '$rating' } } }]),
            Technician.aggregate([{ $group: { _id: null, total: { $sum: '$issuesResolved' } } }]),
            Technician.find().sort({ rating: -1, issuesResolved: -1 }).limit(5).lean(),
            Technician.aggregate([
                {
                    $group: {
                        _id: {
                            year: { $year: '$createdAt' },
                            month: { $month: '$createdAt' },
                        },
                        count: { $sum: 1 },
                        issues: { $sum: '$issuesResolved' },
                    },
                },
                { $sort: { '_id.year': 1, '_id.month': 1 } },
                { $limit: 12 },
            ]),
            // User signups grouped by year+month (mirrors the technician $group)
            User.aggregate([
                {
                    $group: {
                        _id: {
                            year: { $year: '$createdAt' },
                            month: { $month: '$createdAt' },
                        },
                        count: { $sum: 1 },
                    },
                },
                { $sort: { '_id.year': 1, '_id.month': 1 } },
                { $limit: 12 },
            ]),
            // Issue queries
            Issue.countDocuments(),
            Issue.aggregate([
                { $group: { _id: '$status', count: { $sum: 1 } } },
            ]),
            Issue.aggregate([
                { $group: { _id: '$category', count: { $sum: 1 } } },
            ]),
            Issue.aggregate([
                { $group: { _id: '$urgency', count: { $sum: 1 } } },
            ]),
            // User queries
            User.countDocuments(),
            User.aggregate([
                { $group: { _id: '$role', count: { $sum: 1 } } },
            ]),
            User.countDocuments({ isVerified: true }),
        ]);

        const categories = {};
        categoryBreakdown.forEach((c) => {
            categories[c._id] = { count: c.count, avgRating: c.avgRating?.toFixed(2) || '0' };
        });

        // Build status map
        const statusMap = {};
        issuesByStatus.forEach((s) => { statusMap[s._id] = s.count; });

        // Build issue category map
        const issueCategoryMap = {};
        issuesByCategory.forEach((c) => { issueCategoryMap[c._id] = c.count; });

        // Build urgency map
        const urgencyMap = {};
        issuesByUrgency.forEach((u) => { urgencyMap[u._id] = u.count; });

        // Build user role map
        const roleMap = {};
        usersByRole.forEach((r) => { roleMap[r._id] = r.count; });

        // Build a year-month -> user signups map so we can attach a per-month
        // `users` count to each technician growth entry.
        const userGrowthMap = {};
        userMonthlyGrowth.forEach((m) => {
            userGrowthMap[`${m._id.year}-${m._id.month}`] = m.count;
        });

        return NextResponse.json({
            totalTechnicians,
            verifiedCount,
            verifiedPercentage: totalTechnicians > 0 ? ((verifiedCount / totalTechnicians) * 100).toFixed(1) : 0,
            categories,
            avgRating: avgRating[0]?.avg?.toFixed(2) || '0',
            totalIssuesResolved: totalIssuesResolved[0]?.total || 0,
            cityDistribution: cityDistribution.map((c) => ({ city: c._id, count: c.count })),
            ratingDistribution: ratingDistribution.map((r) => ({
                range: `${r._id}-${r._id + 1}`,
                count: r.count,
            })),
            topTechnicians,
            monthlyGrowth: monthlyGrowth.map((m) => ({
                month: new Date(m._id.year, m._id.month - 1).toLocaleString('en-US', { month: 'short' }),
                technicians: m.count,
                issues: m.issues,
                users: userGrowthMap[`${m._id.year}-${m._id.month}`] || 0,
            })),
            // Issue analytics
            issueStats: {
                total: totalIssues,
                pending: statusMap.pending || 0,
                assigned: statusMap.assigned || 0,
                inProgress: statusMap.inProgress || 0,
                completed: statusMap.completed || 0,
                cancelled: statusMap.cancelled || 0,
                byCategory: issueCategoryMap,
                byUrgency: {
                    low: urgencyMap.low || 0,
                    medium: urgencyMap.medium || 0,
                    high: urgencyMap.high || 0,
                    emergency: urgencyMap.emergency || 0,
                },
            },
            // User analytics
            userStats: {
                total: totalUsers,
                customers: roleMap.customer || 0,
                workers: roleMap.worker || 0,
                verified: verifiedUsers,
            },
        });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}
