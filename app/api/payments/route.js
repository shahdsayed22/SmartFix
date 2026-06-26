import { NextResponse } from 'next/server';
import dbConnect from '@/lib/mongodb';
import Payment from '@/models/Payment';
import { getCommissionSettings, computeInvoice, computePayout } from '@/lib/pricing';
import { createInvoice } from '@/lib/paymob';

export async function GET(request) {
    try {
        await dbConnect();
        const { searchParams } = new URL(request.url);

        const page = parseInt(searchParams.get('page')) || 1;
        const limit = parseInt(searchParams.get('limit')) || 20;
        const issueId = searchParams.get('issueId') || '';
        const customerId = searchParams.get('customerId') || '';
        const technicianId = searchParams.get('technicianId') || '';
        const status = searchParams.get('status') || '';
        const sortBy = searchParams.get('sortBy') || 'createdAt';
        const sortOrder = searchParams.get('sortOrder') === 'asc' ? 1 : -1;

        const filter = {};
        if (issueId) filter.issueId = issueId;
        if (customerId) filter.customerId = customerId;
        if (technicianId) filter.technicianId = technicianId;
        if (status) filter.status = status;

        const skip = (page - 1) * limit;
        const [payments, total] = await Promise.all([
            Payment.find(filter)
                .sort({ [sortBy]: sortOrder })
                .skip(skip)
                .limit(limit)
                .lean(),
            Payment.countDocuments(filter),
        ]);

        return NextResponse.json({
            payments,
            pagination: {
                page,
                limit,
                total,
                pages: Math.ceil(total / limit),
            },
        });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 500 });
    }
}

export async function POST(request) {
    try {
        await dbConnect();
        const body = await request.json();

        const base = Number(body.base) || 0;
        if (base <= 0) {
            return NextResponse.json({ error: 'A positive base amount is required' }, { status: 400 });
        }

        // Compute client invoice + worker payout from the commission singleton.
        const settings = await getCommissionSettings();
        const discount = Number(body.discount) || 0;
        const invoice = computeInvoice({ base, settings, discount });
        const payout = computePayout({ base, settings });

        // Create the provider invoice. The active provider is Paymob, so its
        // browser redirect + webhook must land on the Paymob-aware route (the
        // /api/payments/callback route is MyFatoorah/mock only and ignores
        // Paymob's payload). Mock mode points its own URL at /callback instead.
        const origin = new URL(request.url).origin;
        const callbackUrl =
            body.callbackUrl || `${origin}/api/payments/paymob-callback?issueId=${body.issueId || ''}`;
        const providerInvoice = await createInvoice({
            amount: invoice.total,
            customer: {
                name: body.customerName || '',
                email: body.customerEmail || '',
                phone: body.customerPhone || '',
            },
            callbackUrl,
            errorUrl: callbackUrl,
            displayCurrency: invoice.currency,
        });

        const payment = await Payment.create({
            issueId: body.issueId || '',
            ticketId: body.ticketId || '',
            customerId: body.customerId || '',
            technicianId: body.technicianId || '',
            method: body.method || 'card',
            status: 'pending',
            base: invoice.base,
            platformFee: invoice.platformFee,
            vat: invoice.vat,
            discount: invoice.discount,
            total: invoice.total,
            workerCommission: payout.workerCommission,
            payoutAmount: payout.payout,
            currency: invoice.currency,
            provider: 'paymob',
            providerInvoiceId: providerInvoice.invoiceId,
            paymentUrl: providerInvoice.paymentUrl,
            promoCode: body.promoCode || '',
        });

        return NextResponse.json(payment, { status: 201 });
    } catch (error) {
        return NextResponse.json({ error: error.message }, { status: 400 });
    }
}
