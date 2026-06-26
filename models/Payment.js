import mongoose from 'mongoose';

const PaymentSchema = new mongoose.Schema({
    issueId: {
        type: String,
        default: '',
        index: true,
    },
    ticketId: {
        type: String,
        default: '',
    },
    customerId: {
        type: String,
        default: '',
    },
    technicianId: {
        type: String,
        default: '',
    },
    method: {
        type: String,
        enum: ['card', 'meeza', 'fawry', 'wallet'],
        default: 'card',
    },
    status: {
        type: String,
        enum: ['pending', 'paid', 'failed', 'refunded'],
        default: 'pending',
    },
    base: {
        type: Number,
        default: 0,
    },
    platformFee: {
        type: Number,
        default: 0,
    },
    vat: {
        type: Number,
        default: 0,
    },
    discount: {
        type: Number,
        default: 0,
    },
    total: {
        type: Number,
        default: 0,
    },
    workerCommission: {
        type: Number,
        default: 0,
    },
    payoutAmount: {
        type: Number,
        default: 0,
    },
    currency: {
        type: String,
        default: 'EGP',
    },
    provider: {
        type: String,
        default: 'myfatoorah',
    },
    providerInvoiceId: {
        type: String,
        default: '',
    },
    providerPaymentId: {
        type: String,
        default: '',
    },
    paymentUrl: {
        type: String,
        default: '',
    },
    promoCode: {
        type: String,
        default: '',
    },
    createdAt: {
        type: Date,
        default: Date.now,
    },
    paidAt: {
        type: Date,
        default: null,
    },
    updatedAt: {
        type: Date,
        default: Date.now,
    },
});

PaymentSchema.index({ issueId: 1 });
PaymentSchema.index({ customerId: 1 });
PaymentSchema.index({ status: 1 });

export default mongoose.models.Payment || mongoose.model('Payment', PaymentSchema);
