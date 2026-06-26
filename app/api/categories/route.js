import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import ServiceCategory from '@/models/ServiceCategory';

// Static §1 taxonomy — the canonical fallback when the DB collection is empty.
// Keys, labels, icons, colors and default prices match the build contract.
const STATIC_CATEGORIES = [
    { key: 'plumbing', labelAr: 'السباكة', labelEn: 'Plumbing', icon: 'wrench', color: '#1E6FD9', defaultPrice: 180, order: 0, active: true },
    { key: 'electrical', labelAr: 'الكهرباء', labelEn: 'Electrical', icon: 'zap', color: '#EBA110', defaultPrice: 200, order: 1, active: true },
    { key: 'carpentry', labelAr: 'النجارة', labelEn: 'Carpentry', icon: 'hammer', color: '#8A5A3B', defaultPrice: 250, order: 2, active: true },
    { key: 'painting', labelAr: 'الدهانات', labelEn: 'Painting', icon: 'paint-roller', color: '#8E44C4', defaultPrice: 1200, order: 3, active: true },
    { key: 'hvac', labelAr: 'التكييف والتبريد', labelEn: 'HVAC', icon: 'wind', color: '#189FB6', defaultPrice: 350, order: 4, active: true },
    { key: 'cleaning', labelAr: 'التنظيف', labelEn: 'Cleaning', icon: 'spray-can', color: '#DE3F7C', defaultPrice: 300, order: 5, active: true },
    { key: 'appliance_repair', labelAr: 'صيانة الأجهزة', labelEn: 'Appliances', icon: 'washing-machine', color: '#F2700B', defaultPrice: 220, order: 6, active: true },
    { key: 'welding', labelAr: 'اللحام', labelEn: 'Welding', icon: 'flame', color: '#D23A2A', defaultPrice: 280, order: 7, active: true },
    { key: 'tiling', labelAr: 'السيراميك والبلاط', labelEn: 'Tiling', icon: 'grid-3x3', color: '#0E9C8C', defaultPrice: 900, order: 8, active: true },
];

export async function GET() {
    try {
        await dbConnect();
        const categories = await ServiceCategory.find({}).sort({ order: 1 }).lean();
        if (categories.length) {
            return NextResponse.json({ categories, source: 'db' });
        }
        return NextResponse.json({ categories: STATIC_CATEGORIES, source: 'static' });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}

// Admin upsert — accepts a single category or an array of categories, keyed by `key`.
async function upsertCategories(request) {
    await dbConnect();
    const body = await request.json();
    const items = Array.isArray(body) ? body : Array.isArray(body.categories) ? body.categories : [body];

    const results = [];
    for (const item of items) {
        if (!item.key) continue;
        const doc = await ServiceCategory.findOneAndUpdate(
            { key: item.key },
            { $set: item },
            { new: true, upsert: true, runValidators: true, setDefaultsOnInsert: true }
        ).lean();
        results.push(doc);
    }
    return results;
}

export async function POST(request) {
    try {
        const categories = await upsertCategories(request);
        return NextResponse.json({ categories }, { status: 201 });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}

export async function PUT(request) {
    try {
        const categories = await upsertCategories(request);
        return NextResponse.json({ categories });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}

// Admin delete — removes a single category matched by `key` (from query string or body).
export async function DELETE(request) {
    try {
        await dbConnect();
        let key = new URL(request.url).searchParams.get('key');
        if (!key) {
            const body = await request.json().catch(() => ({}));
            key = body && body.key;
        }
        if (!key) {
            return NextResponse.json({ error: 'key is required' }, { status: 400 });
        }
        const deleted = await ServiceCategory.findOneAndDelete({ key }).lean();
        if (!deleted) {
            return NextResponse.json({ error: 'Category not found' }, { status: 404 });
        }
        return NextResponse.json({ deleted });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
