import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/payment.dart';
import '../../models/commission_settings.dart';
import '../../models/issue_model.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_cards.dart';
import '../../widgets/sf_cat_tile.dart';
import '../../widgets/sf_states.dart';
import '../../widgets/sf_feedback.dart';

/// Worker earnings dashboard — total payout, total platform commission, and a
/// list of completed jobs' payouts. Figures come from real [Payment] records
/// when a job has a linked payment; otherwise they are derived from the job's
/// price via [CommissionSettings.computePayout] (the §3 financial model), so
/// every completed job shows an accurate payout even before settlement.
///
/// Design ref: design_reference/.../ar/screens-extra.jsx → EarningsScreen.
class EarningsScreen extends StatefulWidget {
  const EarningsScreen({super.key});

  @override
  State<EarningsScreen> createState() => _EarningsScreenState();
}

class _EarningsScreenState extends State<EarningsScreen> {
  final ApiService _api = ApiService();

  bool _loading = true;
  bool _error = false;

  List<_PayoutRow> _rows = const [];
  double _totalPayout = 0;
  double _totalCommission = 0;
  String _currency = 'EGP';
  // Live wallet balance (Stage 5 ledger) — credited on each settled job,
  // withdrawable by the worker. The total-payout figures above are historical;
  // this is the actual cash available to cash out now.
  double _walletBalance = 0;
  bool _withdrawing = false;

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
    final uid = context.read<AuthService>().uid ??
        context.read<AuthService>().currentUser?.uid;

    if (uid == null || uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (mounted) {
      setState(() {
        _loading = true;
        _error = false;
      });
    }

    try {
      // Commission singleton drives the payout math for unsettled jobs.
      final settingsMap = await _api.getCommissionSettings();
      final settings = CommissionSettings.fromJson(settingsMap);

      // Live wallet balance from the ledger (best-effort — never blocks).
      double walletBalance = 0;
      try {
        final w = await _api.getWallet(uid);
        walletBalance = _toDouble(w['balance']);
      } catch (_) {/* wallet endpoint unavailable — show 0 */}

      // Completed jobs assigned to this worker (filter client-side; the
      // issues feed returns raw maps that also carry price + paymentId).
      final issues = await _api.getIssues(limit: 500);
      final mine = issues.where((m) {
        final tech = (m['assignedTechnicianId'] ?? m['assignedWorkerId'] ?? '')
            .toString();
        final status = (m['status'] ?? '').toString();
        return tech == uid && status == IssueStatus.completed.name;
      }).toList();

      final rows = <_PayoutRow>[];
      double totalPayout = 0;
      double totalCommission = 0;
      String currency = settings.currency;

      for (final m in mine) {
        final issue = Issue.fromMap(m);
        final base = _toDouble(m['price']);

        // Prefer a real Payment record when the job has been settled.
        Payment? payment;
        final paymentId = (m['paymentId'] ?? '').toString();
        if (paymentId.isNotEmpty) {
          try {
            final pm = await _api.getPayment(paymentId);
            payment = Payment.fromJson(pm);
          } catch (_) {
            payment = null; // fall back to computed figures below
          }
        }

        double payout;
        double commission;
        bool settled;
        DateTime when;

        if (payment != null && payment.payoutAmount > 0) {
          payout = payment.payoutAmount;
          commission = payment.workerCommission;
          settled = payment.isPaid;
          currency = payment.currency;
          when = payment.paidAt ?? payment.createdAt;
        } else {
          final computed = settings.computePayout(base: base);
          payout = computed.payout;
          commission = computed.workerCommission;
          settled = false;
          when = issue.updatedAt;
        }

        totalPayout += payout;
        totalCommission += commission;

        rows.add(
          _PayoutRow(
            issue: issue,
            payout: payout,
            commission: commission,
            settled: settled,
            when: when,
          ),
        );
      }

      rows.sort((a, b) => b.when.compareTo(a.when));

      if (!mounted) return;
      setState(() {
        _rows = rows;
        _totalPayout = totalPayout;
        _totalCommission = totalCommission;
        _currency = currency;
        _walletBalance = walletBalance;
        _loading = false;
        _error = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = true;
      });
    }
  }

  // Cash out the wallet (simulated payout). Friendly toast feedback; reloads.
  Future<void> _withdraw() async {
    if (_withdrawing || _walletBalance <= 0) return;
    final uid = context.read<AuthService>().uid ??
        context.read<AuthService>().currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    setState(() => _withdrawing = true);
    try {
      final res = await _api.withdrawWallet(uid);
      if (!mounted) return;
      final amt = _toDouble(res['withdrawn']);
      SfToast.show(
        context,
        '${tr(context, 'تم تحويل')} ${_egp(amt, _currency)} ${tr(context, 'إلى حسابك')}',
        tone: SfTone.success,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      SfToast.show(context, tr(context, 'تعذّر السحب، حاول لاحقًا'),
          tone: SfTone.error);
    } finally {
      if (mounted) setState(() => _withdrawing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SfGradientHeader(
            showBack: true,
            title: tr(context, 'الأرباح'),
            subtitle: tr(context, 'حصيلتك من الوظائف المكتملة'),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.teal,
              onRefresh: _load,
              child: _buildBody(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return _buildLoading();
    if (_error) return _buildError();
    if (_rows.isEmpty) return _buildEmpty();
    return _buildContent();
  }

  Widget _buildLoading() {
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
      children: const [
        SfSkeletonCard(),
        SfSkeletonCard(),
        SfSkeletonCard(),
      ],
    );
  }

  Widget _buildError() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.12),
        SfEmptyState(
          icon: Icons.cloud_off_outlined,
          title: tr(context, 'تعذّر تحميل الأرباح'),
          body: tr(
            context,
            'حدث خطأ أثناء جلب البيانات. تحقّق من الاتصال ثم أعد المحاولة.',
          ),
          action: _RetryButton(onTap: _load),
        ),
      ],
    );
  }

  Widget _buildEmpty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.of(context).size.height * 0.10),
        SfEmptyState(
          icon: Icons.account_balance_wallet_outlined,
          title: tr(context, 'لا توجد أرباح بعد'),
          body: tr(
            context,
            'بمجرد إتمامك أول وظيفة ستظهر هنا حصيلتك وتفاصيل كل تحويل.',
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _TotalPayoutCard(amount: _totalPayout, currency: _currency)
            .animate()
            .fadeIn(duration: 350.ms)
            .slideY(begin: 0.08, duration: 350.ms, curve: Curves.easeOut),
        const SizedBox(height: 14),
        _WalletCard(
          balance: _walletBalance,
          currency: _currency,
          busy: _withdrawing,
          onWithdraw: _withdraw,
        ).animate().fadeIn(duration: 350.ms, delay: 40.ms),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: SfStatCard(
                label: tr(context, 'عدد الوظائف'),
                value: _ar(_rows.length.toString()),
                icon: Icons.check_circle_outline,
                color: AppColors.success,
                bg: AppColors.successBg,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SfStatCard(
                label: tr(context, 'عمولة المنصّة'),
                value: _egp(_totalCommission, _currency),
                icon: Icons.percent_outlined,
                color: AppColors.gold,
                bg: AppColors.warningBg,
              ),
            ),
          ],
        ).animate().fadeIn(duration: 350.ms, delay: 80.ms),
        const SizedBox(height: 22),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 4, bottom: 12),
          child: Text(
            tr(context, 'التحويلات'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
        ),
        ..._rows.asMap().entries.map((entry) {
          final i = entry.key;
          final row = entry.value;
          return Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 11),
            child: _PayoutTile(row: row, currency: _currency)
                .animate()
                .fadeIn(duration: 300.ms, delay: (i * 45).ms)
                .slideX(begin: 0.05, duration: 300.ms),
          );
        }),
      ],
    );
  }
}

// ── Hero total-payout card (navy→teal gradient, white text) ──────────
class _TotalPayoutCard extends StatelessWidget {
  final double amount;
  final String currency;

  const _TotalPayoutCard({required this.amount, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppColors.rCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 18,
            spreadRadius: -8,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            tr(context, 'إجمالي الأرباح'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.white.withValues(alpha: 0.82),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _egp(amount, currency),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              height: 1.05,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.payments_outlined,
                size: 15,
                color: AppColors.gold,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  tr(context, 'صافي حصيلتك بعد خصم عمولة المنصّة'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: AppColors.white.withValues(alpha: 0.78),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Wallet balance + withdraw (Stage 5 ledger) ──────────────────────
class _WalletCard extends StatelessWidget {
  final double balance;
  final String currency;
  final bool busy;
  final VoidCallback onWithdraw;

  const _WalletCard({
    required this.balance,
    required this.currency,
    required this.busy,
    required this.onWithdraw,
  });

  @override
  Widget build(BuildContext context) {
    final canWithdraw = balance > 0 && !busy;
    return Container(
      padding: const EdgeInsets.all(16),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.successBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.account_balance_wallet,
                color: AppColors.success, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'الرصيد المتاح للسحب'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    color: AppColors.midGrey,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _egp(balance, currency),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: canWithdraw ? onWithdraw : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.white,
              disabledBackgroundColor: AppColors.line,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.white),
                  )
                : Text(
                    tr(context, 'سحب'),
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ── Single payout row (category tile + title + amount + state) ───────
class _PayoutTile extends StatelessWidget {
  final _PayoutRow row;
  final String currency;

  const _PayoutTile({required this.row, required this.currency});

  @override
  Widget build(BuildContext context) {
    final issue = row.issue;
    return Container(
      padding: const EdgeInsets.all(13),
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
          SfCatTile(issue.category, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  issue.title.isNotEmpty
                      ? issue.title
                      : tr(context, 'وظيفة مكتملة'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${tr(context, 'العمولة')} ${_egp(row.commission, currency)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.start,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 11.5,
                    color: AppColors.midGrey,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _egp(row.payout, currency),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: AppColors.success,
                ),
              ),
              const SizedBox(height: 5),
              _StatePill(settled: row.settled),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Settled / pending transfer pill ─────────────────────────────────
class _StatePill extends StatelessWidget {
  final bool settled;

  const _StatePill({required this.settled});

  @override
  Widget build(BuildContext context) {
    final color = settled ? AppColors.success : AppColors.warning;
    final bg = settled ? AppColors.successBg : AppColors.warningBg;
    final label = settled ? tr(context, 'تم التحويل') : tr(context, 'قيد التحويل');
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 9,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

// ── Retry button for the error state ────────────────────────────────
class _RetryButton extends StatelessWidget {
  final VoidCallback onTap;

  const _RetryButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.refresh, size: 18, color: AppColors.teal),
      label: Text(
        tr(context, 'إعادة المحاولة'),
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: AppColors.teal,
        ),
      ),
    );
  }
}

// ── Data row ─────────────────────────────────────────────────────────
class _PayoutRow {
  final Issue issue;
  final double payout;
  final double commission;
  final bool settled;
  final DateTime when;

  const _PayoutRow({
    required this.issue,
    required this.payout,
    required this.commission,
    required this.settled,
    required this.when,
  });
}

// ── Helpers ──────────────────────────────────────────────────────────
double _toDouble(dynamic value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0;
}

/// Converts Western digits to Arabic-Indic numerals.
String _ar(String input) {
  const western = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
  const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];
  var out = input;
  for (var i = 0; i < western.length; i++) {
    out = out.replaceAll(western[i], arabic[i]);
  }
  return out;
}

/// Formats a money amount with the currency word (Arabic numerals).
String _egp(double amount, String currency) {
  final rounded = amount.round();
  final label = currency == 'EGP' ? 'ج.م' : currency;
  return '${_ar(rounded.toString())} $label';
}
