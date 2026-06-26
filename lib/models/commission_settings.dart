/// Commission / pricing settings singleton — mirrors Mongo `CommissionSettings`
/// (§4) and the §3 financial model. Source of truth for invoice + payout math.
class CommissionSettings {
  final String key; // singleton key, default 'default'
  final double platformFeePercent;
  final double vatPercent;
  final double workerCommissionPercent;
  final double minPlatformFee;
  final String currency;
  final DateTime updatedAt;

  CommissionSettings({
    this.key = 'default',
    this.platformFeePercent = 10,
    this.vatPercent = 14,
    this.workerCommissionPercent = 15,
    this.minPlatformFee = 0,
    this.currency = 'EGP',
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory CommissionSettings.fromJson(Map<String, dynamic> json) {
    return CommissionSettings(
      key: json['key'] ?? 'default',
      platformFeePercent: _toDouble(json['platformFeePercent'], 10),
      vatPercent: _toDouble(json['vatPercent'], 14),
      workerCommissionPercent: _toDouble(json['workerCommissionPercent'], 15),
      minPlatformFee: _toDouble(json['minPlatformFee'], 0),
      currency: json['currency'] ?? 'EGP',
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        'key': key,
        'platformFeePercent': platformFeePercent,
        'vatPercent': vatPercent,
        'workerCommissionPercent': workerCommissionPercent,
        'minPlatformFee': minPlatformFee,
        'currency': currency,
        'updatedAt': updatedAt.toIso8601String(),
      };

  /// Client-facing invoice (§3 `computeInvoice`). With defaults (10/14),
  /// base 320 → platform 32 → vat 49 → total 401.
  Invoice computeInvoice({required double base, double discount = 0}) {
    final platformFee = _max(
      minPlatformFee,
      (base * platformFeePercent / 100).roundToDouble(),
    );
    final vat = ((base + platformFee) * vatPercent / 100).roundToDouble();
    final total = _max(0, base + platformFee + vat - discount);
    return Invoice(
      base: base,
      platformFee: platformFee,
      vat: vat,
      discount: discount,
      total: total,
      currency: currency,
    );
  }

  /// Worker-facing payout (§3 `computePayout`).
  Payout computePayout({required double base}) {
    final workerCommission =
        (base * workerCommissionPercent / 100).roundToDouble();
    final payout = base - workerCommission;
    return Payout(
      base: base,
      workerCommission: workerCommission,
      payout: payout,
      currency: currency,
    );
  }
}

/// Result of [CommissionSettings.computeInvoice].
class Invoice {
  final double base;
  final double platformFee;
  final double vat;
  final double discount;
  final double total;
  final String currency;

  const Invoice({
    required this.base,
    required this.platformFee,
    required this.vat,
    required this.discount,
    required this.total,
    required this.currency,
  });

  Map<String, dynamic> toJson() => {
        'base': base,
        'platformFee': platformFee,
        'vat': vat,
        'discount': discount,
        'total': total,
        'currency': currency,
      };
}

/// Result of [CommissionSettings.computePayout].
class Payout {
  final double base;
  final double workerCommission;
  final double payout;
  final String currency;

  const Payout({
    required this.base,
    required this.workerCommission,
    required this.payout,
    required this.currency,
  });

  Map<String, dynamic> toJson() => {
        'base': base,
        'workerCommission': workerCommission,
        'payout': payout,
        'currency': currency,
      };
}

double _max(double a, double b) => a > b ? a : b;

double _toDouble(dynamic value, double fallback) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
