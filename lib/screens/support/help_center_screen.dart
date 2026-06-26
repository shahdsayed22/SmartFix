import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_strings.dart';
import '../../theme/app_colors.dart';
import '../../widgets/sf_header.dart';
import 'support_tickets_screen.dart';

/// A single FAQ entry: an Arabic question + answer, grouped under a topic.
class _Faq {
  final String topic;
  final IconData icon;
  final String q;
  final String a;

  const _Faq({
    required this.topic,
    required this.icon,
    required this.q,
    required this.a,
  });
}

// NOTE: static FAQ content, admin-manageable later (ready for backend wiring).
// Customer-facing help: booking / payment / tracking / refunds / complaints /
// offers / pro membership.
const List<_Faq> _kCustomerFaqs = [
  _Faq(
    topic: 'الحجز',
    icon: Icons.event_available,
    q: 'كيف أحجز خدمة على سمارت فيكس؟',
    a: 'اختر فئة الخدمة، صف المشكلة وأضف صورًا إن أمكن، حدّد موقعك ووقتًا '
        'مناسبًا، ثم أكّد الطلب. سيتولّى النظام إسناد فني مناسب لك تلقائيًا.',
  ),
  _Faq(
    topic: 'الحجز',
    icon: Icons.event_available,
    q: 'هل يمكنني تعديل أو إلغاء الحجز؟',
    a: 'نعم، يمكنك تعديل تفاصيل الطلب أو إلغاؤه من شاشة تفاصيل الطلب طالما لم '
        'يبدأ الفني العمل بعد. بعد بدء العمل تواصل مع الدعم لإتمام الإلغاء.',
  ),
  _Faq(
    topic: 'الدفع',
    icon: Icons.payments_outlined,
    q: 'ما طرق الدفع المتاحة؟',
    a: 'يمكنك الدفع نقدًا عند إتمام الخدمة أو عبر المحفظة الإلكترونية والبطاقات. '
        'تظهر تفاصيل الفاتورة كاملة قبل التأكيد.',
  ),
  _Faq(
    topic: 'الدفع',
    icon: Icons.payments_outlined,
    q: 'متى يتم خصم قيمة الخدمة؟',
    a: 'يُحتسب المبلغ بعد إتمام الفني للعمل وموافقتك على الفاتورة. تجد سجل كل '
        'مدفوعاتك في شاشة المحفظة.',
  ),
  _Faq(
    topic: 'التتبّع',
    icon: Icons.location_searching,
    q: 'كيف أتابع حالة طلبي؟',
    a: 'افتح الطلب من قائمة طلباتي لمتابعة مراحله لحظيًا: قيد الإسناد، تم القبول، '
        'في الطريق، جارٍ التنفيذ، ثم مكتمل.',
  ),
  _Faq(
    topic: 'الاسترداد',
    icon: Icons.replay_circle_filled_outlined,
    q: 'كيف أطلب استرداد المبلغ؟',
    a: 'إذا لم تُنفَّذ الخدمة كما هو متفق عليه، افتح نزاعًا من تفاصيل الطلب. '
        'يراجع فريقنا الحالة ويُعيد المبلغ إلى محفظتك عند استحقاقه.',
  ),
  _Faq(
    topic: 'الشكاوى',
    icon: Icons.report_gmailerrorred,
    q: 'كيف أقدّم شكوى على فني؟',
    a: 'من تفاصيل الطلب اختر الإبلاغ عن مشكلة وصف ما حدث. تصل الشكوى لفريق '
        'الجودة الذي يتخذ الإجراء المناسب ويتواصل معك.',
  ),
  _Faq(
    topic: 'العروض',
    icon: Icons.local_offer_outlined,
    q: 'كيف أستفيد من العروض والخصومات؟',
    a: 'تظهر العروض السارية على الشاشة الرئيسية وعند تأكيد الحجز. أدخل كود الخصم '
        'إن وُجد ليُطبَّق على الفاتورة مباشرة.',
  ),
  _Faq(
    topic: 'العضوية المميزة',
    icon: Icons.workspace_premium_outlined,
    q: 'ما مزايا العضوية المميزة (برو)؟',
    a: 'تمنحك العضوية المميزة أولوية في الإسناد، أسعارًا تفضيلية، ودعمًا أسرع. '
        'يمكنك الاشتراك من إعدادات الحساب.',
  ),
];

// NOTE: static FAQ content, admin-manageable later (ready for backend wiring).
// Worker-facing help: accepting jobs / completing / cash / wallet / commission /
// payouts / verification.
const List<_Faq> _kWorkerFaqs = [
  _Faq(
    topic: 'قبول المهام',
    icon: Icons.check_circle_outline,
    q: 'كيف أقبل مهمة جديدة؟',
    a: 'عند إسناد مهمة لك يصلك إشعار، وتظهر في قائمة مهامي. راجع التفاصيل ثم اضغط '
        'قبول لبدء التنفيذ أو رفض مع توضيح السبب.',
  ),
  _Faq(
    topic: 'قبول المهام',
    icon: Icons.check_circle_outline,
    q: 'ماذا يحدث إذا رفضت مهمة كثيرًا؟',
    a: 'الرفض المتكرر قد يؤثّر على تقييمك وأولويتك في الإسناد. احرص على قبول ما '
        'يناسب تخصصك ونطاق عملك.',
  ),
  _Faq(
    topic: 'إتمام العمل',
    icon: Icons.task_alt,
    q: 'كيف أنهي المهمة بشكل صحيح؟',
    a: 'بعد إتمام العمل حدّث حالة الطلب إلى مكتمل وأرفق صور النتيجة إن لزم. '
        'يؤكّد العميل الإتمام لتُحتسب أرباحك.',
  ),
  _Faq(
    topic: 'الدفع النقدي',
    icon: Icons.payments,
    q: 'كيف أتعامل مع الدفع النقدي؟',
    a: 'حصّل المبلغ المتفق عليه الظاهر في الفاتورة فقط. يُخصم نصيب المنصة تلقائيًا '
        'من محفظتك، ويبقى الباقي مستحقًا لك.',
  ),
  _Faq(
    topic: 'المحفظة',
    icon: Icons.account_balance_wallet_outlined,
    q: 'كيف أتابع رصيد محفظتي؟',
    a: 'تعرض شاشة الأرباح والمحفظة رصيدك الحالي، المبالغ المستحقة، والمعاملات '
        'الأخيرة لحظيًا.',
  ),
  _Faq(
    topic: 'العمولة',
    icon: Icons.percent,
    q: 'كيف تُحتسب عمولة المنصة؟',
    a: 'تُخصم نسبة عمولة محدّدة من قيمة كل خدمة مكتملة. تظهر النسبة وتفصيل '
        'الحساب في فاتورة كل مهمة.',
  ),
  _Faq(
    topic: 'التحويلات',
    icon: Icons.account_balance,
    q: 'متى أستلم أرباحي؟',
    a: 'تُحوَّل الأرباح المستحقة إلى حسابك وفق دورة الصرف المعتمدة. تابع حالة كل '
        'تحويل من شاشة الأرباح.',
  ),
  _Faq(
    topic: 'التوثيق',
    icon: Icons.verified_user_outlined,
    q: 'كيف أوثّق حسابي كفني؟',
    a: 'ارفع مستنداتك (الهوية وشهادات الخبرة) من ملفك الشخصي. بعد مراجعة الفريق '
        'يظهر شارة موثّق ويزيد ظهورك للعملاء.',
  ),
];

/// Help Center for SmartFix: a role-segmented FAQ browser. The user picks the
/// customer or worker track, and each track shows topic-grouped, expandable
/// FAQ entries. A bottom contact-support CTA hints at the (upcoming) support
/// channel.
///
/// Static content only — the FAQ lists live in-file ([_kCustomerFaqs] /
/// [_kWorkerFaqs]) and are intended to become admin-manageable later. No API.
class HelpCenterScreen extends StatefulWidget {
  /// Optional initial role: 'worker' selects the worker track, anything else
  /// (or null) defaults to the customer track.
  final String? role;

  const HelpCenterScreen({super.key, this.role});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  // 0 = customer, 1 = worker.
  late int _role;

  @override
  void initState() {
    super.initState();
    _role = (widget.role ?? '').toLowerCase() == 'worker' ? 1 : 0;
  }

  List<_Faq> get _faqs => _role == 1 ? _kWorkerFaqs : _kCustomerFaqs;

  /// FAQs grouped in their original order under topic headings.
  List<MapEntry<String, List<_Faq>>> get _grouped {
    final map = <String, List<_Faq>>{};
    for (final f in _faqs) {
      map.putIfAbsent(f.topic, () => <_Faq>[]).add(f);
    }
    return map.entries.toList();
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
              title: tr(context, 'المساعدة والدعم'),
              subtitle: tr(context, 'أسئلة شائعة وإرشادات سريعة'),
              showBack: true,
              child: _roleTabs(),
            ),
            Expanded(child: _body()),
          ],
        ),
      ),
    );
  }

  Widget _roleTabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(child: _roleTab(0, tr(context, 'للعملاء'), Icons.person_outline)),
          Expanded(child: _roleTab(1, tr(context, 'للفنيين'), Icons.handyman_outlined)),
        ],
      ),
    );
  }

  Widget _roleTab(int value, String label, IconData icon) {
    final selected = _role == value;
    return GestureDetector(
      onTap: () {
        if (_role != value) setState(() => _role = value);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppColors.primary : AppColors.white,
            ),
            const SizedBox(width: 7),
            Text(
              label,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: selected ? AppColors.primary : AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body() {
    final groups = _grouped;
    return ListView(
      padding: const EdgeInsetsDirectional.fromSTEB(18, 18, 18, 28),
      children: [
        // Direct-contact channels (design: live chat / call / email).
        _contactCard(
          Icons.chat_bubble_outline,
          AppColors.teal,
          tr(context, 'الدردشة المباشرة'),
          tr(context, 'متاح ٢٤/٧'),
          onTap: _onContactSupport,
        ),
        const SizedBox(height: 10),
        _contactCard(
          Icons.chat,
          AppColors.teal,
          tr(context, 'واتساب'),
          '+20 100 160 0000',
          ltrSub: true,
          onTap: () => _openWhatsApp('201001600000'),
        ),
        const SizedBox(height: 10),
        _contactCard(
          Icons.phone_outlined,
          AppColors.primary,
          tr(context, 'اتصل بنا'),
          '١٦٠٠٠',
          ltrSub: true,
          onTap: () => _launchUri(Uri(scheme: 'tel', path: '16000')),
        ),
        const SizedBox(height: 10),
        _contactCard(
          Icons.mail_outline,
          AppColors.goldDeep,
          tr(context, 'البريد الإلكتروني'),
          'support@smartfix.eg',
          ltrSub: true,
          onTap: () => _launchUri(
            Uri(scheme: 'mailto', path: 'support@smartfix.eg'),
          ),
        ),
        _groupTitle(tr(context, 'الأسئلة الشائعة')),
        for (final g in groups) ...[
          _topicCard(g.value.first.icon, g.key, g.value),
          const SizedBox(height: 14),
        ],
        const SizedBox(height: 2),
        _reportProblemButton(),
      ],
    );
  }

  /// A tappable support-contact row: tinted icon tile + label/sub + chevron.
  Widget _contactCard(
    IconData icon,
    Color tone,
    String label,
    String sub, {
    bool ltrSub = false,
    required VoidCallback onTap,
  }) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.rCard),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.rCard),
            border: Border.all(color: AppColors.lineSoft),
            boxShadow: const [
              BoxShadow(
                color: AppColors.navyShadow,
                blurRadius: 14,
                spreadRadius: -11,
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
                  color: tone.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: tone),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      textAlign: TextAlign.start,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Directionality(
                      textDirection:
                          ltrSub ? TextDirection.ltr : TextDirection.rtl,
                      child: Text(
                        sub,
                        textAlign: TextAlign.start,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12,
                          color: AppColors.midGrey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left,
                size: 18,
                color: AppColors.midGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Section heading in the muted GroupTitle style from the design.
  Widget _groupTitle(String text) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(4, 18, 4, 8),
      child: Text(
        text,
        textAlign: TextAlign.start,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppColors.midGrey,
        ),
      ),
    );
  }

  Widget _topicCard(IconData icon, String topic, List<_Faq> items) {
    return Container(
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
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 15, 16, 5),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: AppColors.primary),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    tr(context, topic),
                    textAlign: TextAlign.start,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.charcoal,
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (int i = 0; i < items.length; i++) ...[
            if (i == 0)
              const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
            _faqTile(items[i]),
            if (i < items.length - 1)
              const Divider(height: 1, thickness: 1, color: AppColors.lineSoft),
          ],
        ],
      ),
    );
  }

  Widget _faqTile(_Faq faq) {
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        childrenPadding: const EdgeInsetsDirectional.fromSTEB(16, 0, 16, 15),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        // Design uses a chevron that flips down -> up on expand. ExpansionTile
        // rotates its trailing icon 0.5 turn, so an expand_more reads as a
        // chevron-down collapsed and chevron-up expanded.
        iconColor: AppColors.midGrey,
        collapsedIconColor: AppColors.midGrey,
        trailing: const Icon(Icons.expand_more, size: 22),
        title: Text(
          tr(context, faq.q),
          textAlign: TextAlign.start,
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: AppColors.charcoal,
          ),
        ),
        children: [
          Text(
            tr(context, faq.a),
            textAlign: TextAlign.start,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              height: 1.7,
              color: AppColors.darkGrey,
            ),
          ),
        ],
      ),
    );
  }

  /// Ghost full-width "report a problem" action (design bottom CTA).
  Widget _reportProblemButton() {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppColors.rBtn),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.rBtn),
        onTap: _onContactSupport,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.secondaryBg.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(AppColors.rBtn),
            border: Border.all(color: AppColors.lineSoft),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.flag_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                tr(context, 'الإبلاغ عن مشكلة في التطبيق'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Routes the report / "contact us" CTA to the support-tickets screen, where
  /// the user can open a ticket or reach the smart assistant.
  void _onContactSupport() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SupportTicketsScreen()),
    );
  }

  /// Opens a WhatsApp chat with the given international number (digits only).
  Future<void> _openWhatsApp(String number) {
    return _launchUri(Uri.parse('https://wa.me/$number'));
  }

  /// Launches an external URI (tel / mailto / https) with a capability guard
  /// and a fallback snackbar when no handler is available.
  Future<void> _launchUri(Uri uri) async {
    try {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (ok) return;
      }
    } catch (_) {
      // Fall through to the failure snackbar below.
    }
    if (!mounted) return;
    _showSnack(tr(context, 'تعذّر فتح هذه القناة'));
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.charcoal,
          content: Text(
            message,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              color: AppColors.white,
            ),
          ),
        ),
      );
  }
}
