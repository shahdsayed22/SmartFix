import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../models/payment.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_states.dart';

/// Customer invoices / receipts screen.
///
/// Lists the signed-in customer's **paid** [Payment] records (newest first).
/// Each row shows the total, a paid badge and the date; tapping a row expands
/// the full base / platform-fee / VAT / total breakdown.
///
/// The Next.js dashboard exposes a list endpoint at
/// `GET /api/payments?customerId=…&status=paid` (see app/api/payments/route.js);
/// [ApiService] only carries the single-record getters, so this screen issues
/// the list request itself, mirroring the same base-URL resolution.
class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  Future<List<Payment>>? _future;
  String? _expandedId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final user = context.read<AuthService>().currentUser;
    final uid = user?.uid;
    if (uid == null || uid.isEmpty) {
      _future = Future.value(<Payment>[]);
      return;
    }
    _future = _fetchInvoices(uid);
  }

  // ── Data ─────────────────────────────────────────────────────────

  // Deployed Vercel API by default; override for local dev with
  //   --dart-define=API_BASE=http://192.168.1.35:3000/api
  static const String _prodApiBase = 'https://smartfix-six.vercel.app/api';

  static String get _baseUrl {
    const override = String.fromEnvironment('API_BASE');
    if (override.isNotEmpty) return override;
    if (kIsWeb) {
      // Deployed PWA: API is same-origin under /api. Local LAN dev: same host
      // on port 3000 (use the override above to point at the dev server).
      final host = Uri.base.host;
      final isLocal = host == 'localhost' ||
          host == '127.0.0.1' ||
          RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
      return isLocal ? 'http://$host:3000/api' : '${Uri.base.origin}/api';
    }
    // Native platforms → the deployed Vercel API.
    return _prodApiBase;
  }

  Future<List<Payment>> _fetchInvoices(String customerId) async {
    final uri = Uri.parse('$_baseUrl/payments').replace(
      queryParameters: {
        'customerId': customerId,
        'status': 'paid',
        'sortBy': 'createdAt',
        'sortOrder': 'desc',
        'limit': '100',
      },
    );

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('Failed to fetch invoices: ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    final list = List<Map<String, dynamic>>.from(data['payments'] ?? const []);
    return list.map(Payment.fromJson).toList();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  // ── UI ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SfGradientHeader(
            title: tr(context, 'الفواتير والإيصالات'),
            subtitle: tr(context, 'سجل مدفوعاتك المكتملة'),
            showBack: true,
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: FutureBuilder<List<Payment>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _loading();
                  }
                  if (snapshot.hasError) {
                    return _error();
                  }
                  final invoices = snapshot.data ?? const <Payment>[];
                  if (invoices.isEmpty) {
                    return _empty();
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 28),
                    itemCount: invoices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final inv = invoices[i];
                      return _InvoiceCard(
                        payment: inv,
                        expanded: _expandedId == inv.id,
                        onTap: () => setState(() {
                          _expandedId =
                              _expandedId == inv.id ? null : inv.id;
                        }),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _loading() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 28),
      children: const [
        SfSkeletonCard(),
        SizedBox(height: 12),
        SfSkeletonCard(),
        SizedBox(height: 12),
        SfSkeletonCard(),
      ],
    );
  }

  Widget _empty() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        SfEmptyState(
          icon: Icons.receipt_long_outlined,
          title: tr(context, 'لا توجد فواتير بعد'),
          body: tr(
            context,
            'ستظهر فواتيرك وإيصالاتك هنا بعد إتمام أي عملية دفع.',
          ),
        ),
      ],
    );
  }

  Widget _error() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        SfEmptyState(
          icon: Icons.cloud_off_outlined,
          title: tr(context, 'تعذر تحميل الفواتير'),
          body: tr(
            context,
            'حدث خطأ أثناء جلب الفواتير. تحقق من اتصالك ثم حاول مرة أخرى.',
          ),
          action: OutlinedButton.icon(
            onPressed: _refresh,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.line),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(
              tr(context, 'إعادة المحاولة'),
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A single invoice row: a receipt-icon tile, total + paid badge + date, and
/// an expandable base / platform-fee / VAT / total breakdown.
class _InvoiceCard extends StatelessWidget {
  final Payment payment;
  final bool expanded;
  final VoidCallback onTap;

  const _InvoiceCard({
    required this.payment,
    required this.expanded,
    required this.onTap,
  });

  String _money(BuildContext context, double v) {
    final n = v.toStringAsFixed(v.truncateToDouble() == v ? 0 : 2);
    return '$n ${tr(context, 'ج.م')}';
  }

  String _date(DateTime d) => intl.DateFormat('yyyy/MM/dd').format(d);

  String _methodLabel(BuildContext context) {
    switch (payment.method) {
      case 'card':
        return tr(context, 'بطاقة');
      case 'meeza':
        return tr(context, 'ميزة');
      case 'fawry':
        return tr(context, 'فوري');
      case 'wallet':
        return tr(context, 'محفظة');
      default:
        return tr(context, 'دفع');
    }
  }

  @override
  Widget build(BuildContext context) {
    final when = payment.paidAt ?? payment.createdAt;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.rCard),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.rCard),
            border: Border.all(color: AppColors.lineSoft),
            boxShadow: const [
              BoxShadow(
                color: AppColors.cardShadow,
                blurRadius: 12,
                offset: Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.successBg,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        size: 22,
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _money(context, payment.total),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.charcoal,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${_methodLabel(context)} · ${_date(when)}',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: AppColors.midGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _PaidBadge(),
                        const SizedBox(height: 8),
                        Icon(
                          expanded
                              ? Icons.expand_less
                              : Icons.expand_more,
                          size: 20,
                          color: AppColors.midGrey,
                        ),
                      ],
                    ),
                  ],
                ),
                AnimatedCrossFade(
                  duration: const Duration(milliseconds: 220),
                  crossFadeState: expanded
                      ? CrossFadeState.showFirst
                      : CrossFadeState.showSecond,
                  firstChild: _breakdown(context),
                  secondChild: const SizedBox(width: double.infinity),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _breakdown(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 14),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.lineSoft),
        ),
        child: Column(
          children: [
            _row(context, tr(context, 'قيمة الخدمة'), payment.base),
            const SizedBox(height: 9),
            _row(
              context,
              tr(context, 'رسوم المنصة'),
              payment.platformFee,
            ),
            const SizedBox(height: 9),
            _row(context, tr(context, 'ضريبة القيمة المضافة'), payment.vat),
            if (payment.discount > 0) ...[
              const SizedBox(height: 9),
              _row(
                context,
                tr(context, 'الخصم'),
                payment.discount,
                negative: true,
              ),
            ],
            const SizedBox(height: 11),
            const Divider(height: 1, color: AppColors.line),
            const SizedBox(height: 11),
            _row(
              context,
              tr(context, 'الإجمالي'),
              payment.total,
              emphasized: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    double value, {
    bool emphasized = false,
    bool negative = false,
  }) {
    final color = emphasized ? AppColors.charcoal : AppColors.darkGrey;
    final amount =
        '${negative ? '−' : ''}${_money(context, value)}';
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: emphasized ? 14.5 : 13,
              fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
              color: color,
            ),
          ),
        ),
        Text(
          amount,
          textDirection: TextDirection.ltr,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: emphasized ? 15 : 13,
            fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
            color: negative
                ? AppColors.success
                : (emphasized ? AppColors.primary : AppColors.charcoal),
          ),
        ),
      ],
    );
  }
}

class _PaidBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.successBg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle, size: 13, color: AppColors.success),
          const SizedBox(width: 4),
          Text(
            tr(context, 'مدفوعة'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColors.success,
            ),
          ),
        ],
      ),
    );
  }
}
