import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/payment.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_states.dart';
import '../../widgets/smart_button.dart';
import 'invoices_screen.dart';

/// A single wallet transaction derived from a real [Payment] record.
class _WalletTx {
  final String title;
  final String subtitleLabel; // method · time
  final double amount; // negative = spend, positive = refund/credit
  final String statusKey; // 'paid' | 'pending' | 'refunded' | 'failed'
  final String currency;
  final DateTime at;

  const _WalletTx({
    required this.title,
    required this.subtitleLabel,
    required this.amount,
    required this.statusKey,
    required this.currency,
    required this.at,
  });
}

/// Wallet summary for the current user: a balance/spend hero, quick stat
/// cards, and a recent-transactions list built from the customer's real
/// payment records.
///
/// Fully wired to [ApiService.getPayments] (filtered by the authenticated
/// customer id) with loading (skeleton), empty, and error states. Balance,
/// pending totals and the transaction list all come from real payment
/// fields (total / status / method / paidAt / createdAt). No mock data.
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _error = false;

  String _currency = 'EGP';
  List<_WalletTx> _txns = const [];

  double _totalSpent = 0;
  double _pending = 0;
  int _paidCount = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final uid = context.read<AuthService>().uid;
    // Guest / empty uid → no user-scoped payments to show.
    if (uid == null || uid.isEmpty || uid.startsWith('guest')) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = false;
          _txns = const [];
          _totalSpent = 0;
          _pending = 0;
          _paidCount = 0;
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    try {
      final raw = await _api.getPayments(customerId: uid);
      final payments = raw.map(Payment.fromJson).toList()
        ..sort((a, b) => _txDate(b).compareTo(_txDate(a)));

      final txns = <_WalletTx>[];
      double spent = 0;
      double pending = 0;
      int paidCount = 0;
      String currency = 'EGP';

      for (final p in payments) {
        if (p.currency.isNotEmpty) currency = p.currency;

        switch (p.status) {
          case 'paid':
            spent += p.total;
            paidCount++;
            break;
          case 'pending':
            pending += p.total;
            break;
          // refunded / failed → not counted toward spend or pending.
        }

        // Refunds read as a credit (positive); everything else as spend.
        final isRefund = p.status == 'refunded';
        txns.add(_WalletTx(
          title: _title(p),
          subtitleLabel: _methodLabel(p.method),
          amount: isRefund ? p.total : -p.total,
          statusKey: p.status,
          currency: p.currency.isEmpty ? 'EGP' : p.currency,
          at: _txDate(p),
        ));
      }

      if (mounted) {
        setState(() {
          _currency = currency;
          _txns = txns;
          _totalSpent = spent;
          _pending = pending;
          _paidCount = paidCount;
          _loading = false;
          _error = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = true;
        });
      }
    }
  }

  /// Best timestamp for a payment: paid time if settled, else created.
  DateTime _txDate(Payment p) => p.paidAt ?? p.createdAt;

  /// A human title for a payment row (falls back to the issue reference).
  String _title(Payment p) {
    if (p.issueId.isNotEmpty) {
      return '${tr(context, 'خدمة')} #${_shortId(p.issueId)}';
    }
    return tr(context, 'دفعة');
  }

  String _shortId(String id) =>
      id.length <= 6 ? id : id.substring(id.length - 6);

  /// Arabic label for a payment method.
  String _methodLabel(String method) {
    switch (method) {
      case 'card':
        return tr(context, 'بطاقة');
      case 'meeza':
        return tr(context, 'ميزة');
      case 'fawry':
        return tr(context, 'فوري');
      case 'wallet':
        return tr(context, 'محفظة');
      default:
        return tr(context, 'دفع إلكتروني');
    }
  }

  String _egp(double v) {
    final n = v.abs();
    final s = n.toStringAsFixed(n.truncateToDouble() == n ? 0 : 2);
    // group thousands
    final parts = s.split('.');
    final intPart = parts[0];
    final buf = StringBuffer();
    for (int k = 0; k < intPart.length; k++) {
      if (k > 0 && (intPart.length - k) % 3 == 0) buf.write(',');
      buf.write(intPart[k]);
    }
    final grouped = parts.length > 1 ? '${buf.toString()}.${parts[1]}' : buf.toString();
    return '$grouped $_currency';
  }

  String _timeAgo(BuildContext context, DateTime at) {
    final d = DateTime.now().difference(at);
    if (d.inMinutes < 1) return tr(context, 'الآن');
    if (d.inMinutes < 60) return '${d.inMinutes} ${tr(context, 'دقيقة')}';
    if (d.inHours < 24) return '${d.inHours} ${tr(context, 'ساعة')}';
    if (d.inDays < 30) return '${d.inDays} ${tr(context, 'يوم')}';
    final months = (d.inDays / 30).floor();
    return '$months ${tr(context, 'شهر')}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            SfGradientHeader(
              title: tr(context, 'المحفظة'),
              subtitle: tr(context, 'رصيدك ومعاملاتك الأخيرة'),
              showBack: true,
              actions: [
                Material(
                  color: AppColors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _openInvoices,
                    child: const SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.receipt_long,
                        size: 19,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
        children: const [
          SfSkeletonCard(),
          SfSkeletonCard(),
          SfSkeletonCard(),
        ],
      );
    }

    if (_error) {
      return SfEmptyState(
        icon: Icons.wifi_off_rounded,
        title: tr(context, 'تعذّر تحميل المحفظة'),
        body: tr(context, 'تحقّق من اتصالك بالإنترنت ثم حاول مرة أخرى.'),
        action: SmartButton(
          label: tr(context, 'إعادة المحاولة'),
          icon: Icons.refresh,
          width: 200,
          onPressed: _load,
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
        children: [
          _balanceCard(),
          const SizedBox(height: 14),
          _statsRow(),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SmartButton(
                  label: tr(context, 'الفواتير'),
                  icon: Icons.receipt_long,
                  onPressed: _openInvoices,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: SmartButton(
                  label: tr(context, 'تحديث'),
                  icon: Icons.refresh,
                  isOutlined: true,
                  onPressed: _load,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 12, start: 2),
            child: Text(
              tr(context, 'المعاملات الأخيرة'),
              textAlign: TextAlign.start,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.charcoal,
              ),
            ),
          ),
          if (_txns.isEmpty)
            SfEmptyState(
              icon: Icons.account_balance_wallet_outlined,
              title: tr(context, 'لا توجد معاملات بعد'),
              body: tr(
                context,
                'ستظهر هنا مدفوعاتك بعد إتمام أول خدمة عبر سمارت فيكس.',
              ),
            )
          else
            ..._txns.map(_txTile),
        ],
      ),
    );
  }

  Widget _balanceCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppColors.rCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 18,
            spreadRadius: -8,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet,
                size: 16,
                color: AppColors.white.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 7),
              Text(
                tr(context, 'إجمالي مدفوعاتك'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 13,
                  color: AppColors.white.withValues(alpha: 0.82),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _egp(_totalSpent),
            textAlign: TextAlign.start,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.1,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.timelapse, size: 14, color: AppColors.gold),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${tr(context, 'قيد التنفيذ')}: ${_egp(_pending)}',
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    color: AppColors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsRow() {
    return Row(
      children: [
        Expanded(child: _miniStat(
          tr(context, 'خدمات مدفوعة'),
          '$_paidCount',
          Icons.check_circle,
          AppColors.success,
          AppColors.successBg,
        )),
        const SizedBox(width: 11),
        Expanded(child: _miniStat(
          tr(context, 'قيد التنفيذ'),
          _egp(_pending),
          Icons.timelapse,
          AppColors.warning,
          AppColors.warningBg,
        )),
      ],
    );
  }

  Widget _miniStat(
    String label,
    String value,
    IconData icon,
    Color color,
    Color bg,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.lineSoft),
        boxShadow: const [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 14,
            spreadRadius: -10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(height: 11),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: AppColors.midGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _txTile(_WalletTx tx) {
    final isCredit = tx.amount > 0;
    final tone = isCredit ? AppColors.success : AppColors.darkGrey;
    final iconTone = isCredit ? AppColors.success : AppColors.primary;
    final iconBg =
        isCredit ? AppColors.successBg : AppColors.secondaryBg;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.rCard),
        border: Border.all(color: AppColors.lineSoft),
        boxShadow: const [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 14,
            spreadRadius: -10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              isCredit ? Icons.south_west : Icons.north_east,
              size: 20,
              color: iconTone,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${tx.subtitleLabel} · ${_timeAgo(context, tx.at)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: AppColors.midGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(
              '${isCredit ? '+' : '−'}${_egp(tx.amount)}',
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openInvoices() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InvoicesScreen()),
    );
  }
}
