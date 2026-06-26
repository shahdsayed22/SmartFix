/// Payment model — mirrors Mongo `Payment` schema (§4) and the §3 financial
/// model. `method` ∈ {card, meeza, fawry, wallet}; `status` ∈ {pending, paid,
/// failed, refunded}.
class Payment {
  final String id; // Mongo _id (if present)
  final String issueId;
  final String ticketId; // optional
  final String customerId;
  final String technicianId;
  final String method;
  final String status;
  final double base;
  final double platformFee;
  final double vat;
  final double discount;
  final double total;
  final double workerCommission;
  final double payoutAmount;
  final String currency;
  final String provider;
  final String providerInvoiceId;
  final String providerPaymentId;
  final String paymentUrl;
  final String promoCode;
  final DateTime createdAt;
  final DateTime? paidAt;
  final DateTime updatedAt;

  Payment({
    this.id = '',
    this.issueId = '',
    this.ticketId = '',
    this.customerId = '',
    this.technicianId = '',
    this.method = 'card',
    this.status = 'pending',
    this.base = 0,
    this.platformFee = 0,
    this.vat = 0,
    this.discount = 0,
    this.total = 0,
    this.workerCommission = 0,
    this.payoutAmount = 0,
    this.currency = 'EGP',
    this.provider = 'myfatoorah',
    this.providerInvoiceId = '',
    this.providerPaymentId = '',
    this.paymentUrl = '',
    this.promoCode = '',
    DateTime? createdAt,
    this.paidAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Payment.fromJson(Map<String, dynamic> json) {
    return Payment(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      issueId: json['issueId'] ?? '',
      ticketId: json['ticketId'] ?? '',
      customerId: json['customerId'] ?? '',
      technicianId: json['technicianId'] ?? '',
      method: json['method'] ?? 'card',
      status: json['status'] ?? 'pending',
      base: _toDouble(json['base']),
      platformFee: _toDouble(json['platformFee']),
      vat: _toDouble(json['vat']),
      discount: _toDouble(json['discount']),
      total: _toDouble(json['total']),
      workerCommission: _toDouble(json['workerCommission']),
      payoutAmount: _toDouble(json['payoutAmount']),
      currency: json['currency'] ?? 'EGP',
      provider: json['provider'] ?? 'myfatoorah',
      providerInvoiceId: (json['providerInvoiceId'] ?? '').toString(),
      providerPaymentId: (json['providerPaymentId'] ?? '').toString(),
      paymentUrl: json['paymentUrl'] ?? '',
      promoCode: json['promoCode'] ?? '',
      createdAt: _parseDate(json['createdAt']),
      paidAt: json['paidAt'] == null ? null : _parseDate(json['paidAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) '_id': id,
        'issueId': issueId,
        'ticketId': ticketId,
        'customerId': customerId,
        'technicianId': technicianId,
        'method': method,
        'status': status,
        'base': base,
        'platformFee': platformFee,
        'vat': vat,
        'discount': discount,
        'total': total,
        'workerCommission': workerCommission,
        'payoutAmount': payoutAmount,
        'currency': currency,
        'provider': provider,
        'providerInvoiceId': providerInvoiceId,
        'providerPaymentId': providerPaymentId,
        'paymentUrl': paymentUrl,
        'promoCode': promoCode,
        'createdAt': createdAt.toIso8601String(),
        'paidAt': paidAt?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  bool get isPaid => status == 'paid';
}

double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
