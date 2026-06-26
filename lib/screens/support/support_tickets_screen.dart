import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../models/ticket.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_states.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/smart_text_field.dart';
import '../../widgets/sf_feedback.dart';
import '../chat/chatbot_screen.dart';
import 'support_assistant_screen.dart';
import 'ticket_detail_screen.dart';

/// Lists the current user's support tickets (subject, category, status,
/// last-updated), lets them open a ticket, create a new one via a sheet
/// form, or jump into the smart-assistant chatbot. Backed by the REST API
/// (`ApiService.getTickets` / `createTicket`).
class SupportTicketsScreen extends StatefulWidget {
  const SupportTicketsScreen({super.key});

  @override
  State<SupportTicketsScreen> createState() => _SupportTicketsScreenState();
}

class _SupportTicketsScreenState extends State<SupportTicketsScreen> {
  final ApiService _api = ApiService();
  Future<List<Ticket>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final user = context.read<AuthService>().currentUser;
    if (user == null) {
      _future = Future.value(<Ticket>[]);
      return;
    }
    _future = _api.getTickets(customerId: user.uid).then(
          (rows) => rows.map((m) => Ticket.fromJson(m)).toList()
            ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
        );
  }

  Future<void> _refresh() async {
    setState(_load);
    await _future;
  }

  void _openTicket(Ticket ticket) {
    final id = ticket.id.isNotEmpty ? ticket.id : ticket.ticketId;
    if (id.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => TicketDetailScreen(ticketId: id)),
    ).then((_) {
      if (mounted) setState(_load);
    });
  }

  void _openChatbot() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ChatbotScreen()),
    ).then((_) {
      if (mounted) setState(_load);
    });
  }

  void _openAssistant() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SupportAssistantScreen()),
    ).then((_) {
      if (mounted) setState(_load);
    });
  }

  Future<void> _createTicket() async {
    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    final created = await SfSheet.show<bool>(
      context,
      builder: (ctx) => _NewTicketSheet(
        api: _api,
        customerId: user.uid,
        customerName: user.name,
      ),
    );

    if (created == true && mounted) {
      setState(_load);
    }
  }

  @override
  void dispose() {
    _api.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SfGradientHeader(
            title: tr(context, 'الدعم والمساعدة'),
            subtitle: tr(context, 'تذاكرك وطلبات الدعم'),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _refresh,
              child: FutureBuilder<List<Ticket>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 24),
                      children: [
                        _ChatbotEntry(onTap: _openChatbot),
                        const SizedBox(height: 16),
                        const SfSkeletonCard(),
                        const SizedBox(height: 10),
                        const SfSkeletonCard(),
                        const SizedBox(height: 10),
                        const SfSkeletonCard(),
                      ],
                    );
                  }

                  if (snapshot.hasError) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding:
                          const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 24),
                      children: [
                        _ChatbotEntry(onTap: _openChatbot),
                        const SizedBox(height: 60),
                        SfEmptyState(
                          icon: Icons.wifi_off_rounded,
                          title: tr(context, 'تعذّر تحميل التذاكر'),
                          body: tr(
                            context,
                            'تحقّق من اتصالك بالإنترنت ثم حاول مرة أخرى.',
                          ),
                          action: SmartButton(
                            label: tr(context, 'إعادة المحاولة'),
                            icon: Icons.refresh,
                            onPressed: () => setState(_load),
                          ),
                        ),
                      ],
                    );
                  }

                  final tickets = snapshot.data ?? <Ticket>[];

                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding:
                        const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 24),
                    children: [
                      _ChatbotEntry(onTap: _openChatbot),
                      const SizedBox(height: 10),
                      _AssistantEntry(onTap: _openAssistant),
                      const SizedBox(height: 18),
                      Padding(
                        padding:
                            const EdgeInsetsDirectional.only(start: 4, end: 4),
                        child: Row(
                          children: [
                            Text(
                              tr(context, 'تذاكر الدعم'),
                              style: GoogleFonts.ibmPlexSansArabic(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: AppColors.charcoal,
                              ),
                            ),
                            const Spacer(),
                            if (tickets.isNotEmpty)
                              Text(
                                '${tickets.length}',
                                style: GoogleFonts.ibmPlexSansArabic(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.midGrey,
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (tickets.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: SfEmptyState(
                            icon: Icons.confirmation_number_outlined,
                            title: tr(context, 'لا توجد تذاكر بعد'),
                            body: tr(
                              context,
                              'أنشئ تذكرة دعم جديدة وسيتواصل معك فريقنا في أقرب وقت.',
                            ),
                            action: SmartButton(
                              label: tr(context, 'تذكرة جديدة'),
                              icon: Icons.add,
                              onPressed: _createTicket,
                            ),
                          ),
                        )
                      else
                        ...tickets.map(
                          (t) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _TicketCard(
                              ticket: t,
                              onTap: () => _openTicket(t),
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createTicket,
        backgroundColor: AppColors.navy,
        foregroundColor: AppColors.white,
        icon: const Icon(Icons.add),
        label: Text(
          tr(context, 'تذكرة جديدة'),
          style: GoogleFonts.ibmPlexSansArabic(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ─── Smart-assistant entry card ─────────────────────────────────────

class _ChatbotEntry extends StatelessWidget {
  final VoidCallback onTap;

  const _ChatbotEntry({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppColors.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.rCard),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(AppColors.rCard),
            boxShadow: const [
              BoxShadow(
                color: AppColors.navyShadow,
                blurRadius: 16,
                spreadRadius: -6,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.smart_toy_outlined,
                    color: AppColors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'محادثة المساعد الذكي'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr(context, 'احصل على مساعدة فورية على مدار الساعة'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          color: AppColors.white.withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left,
                  color: AppColors.white.withValues(alpha: 0.85),
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Support assistant entry (lighter card, distinct from triage bot) ──

class _AssistantEntry extends StatelessWidget {
  final VoidCallback onTap;

  const _AssistantEntry({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppColors.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.rCard),
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.rCard),
            border: Border.all(color: AppColors.lineSoft),
          ),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr(context, 'مساعد الدعم'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        tr(context, 'مشاكل الطلبات والدفع — وحوّلني لموظف عند الحاجة'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 12.5,
                          color: AppColors.midGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left,
                  color: AppColors.midGrey,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Ticket row card ────────────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  final Ticket ticket;
  final VoidCallback onTap;

  const _TicketCard({required this.ticket, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cat = _ticketCategoryMeta(ticket.category);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppColors.rCard),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.rCard),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cat.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(cat.icon, size: 20, color: cat.color),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ticket.subject.isNotEmpty
                                ? ticket.subject
                                : tr(context, 'تذكرة دعم'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.charcoal,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            tr(context, cat.label),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 12,
                              color: AppColors.midGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TicketStatusBadge(status: ticket.status),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (ticket.ticketId.isNotEmpty) ...[
                      Icon(
                        Icons.tag,
                        size: 13,
                        color: AppColors.midGrey,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        ticket.ticketId,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.midGrey,
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Icon(
                      Icons.schedule,
                      size: 13,
                      color: AppColors.midGrey,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        timeago.format(ticket.updatedAt),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          color: AppColors.midGrey,
                        ),
                      ),
                    ),
                    if (ticket.messages.isNotEmpty) ...[
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 13,
                        color: AppColors.midGrey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${ticket.messages.length}',
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          color: AppColors.midGrey,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rounded status pill for a ticket's string status — mirrors the visual
/// style of [SfStatusBadge] but keyed off the ticket lifecycle
/// (open / pending / resolved / closed).
class _TicketStatusBadge extends StatelessWidget {
  final String status;

  const _TicketStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final meta = _ticketStatusMeta(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: meta.bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: meta.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            tr(context, meta.label),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: meta.color,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── New-ticket sheet form ──────────────────────────────────────────

class _NewTicketSheet extends StatefulWidget {
  final ApiService api;
  final String customerId;
  final String customerName;

  const _NewTicketSheet({
    required this.api,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<_NewTicketSheet> createState() => _NewTicketSheetState();
}

class _NewTicketSheetState extends State<_NewTicketSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subjectCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _category = 'general';
  String _priority = 'medium';
  bool _submitting = false;

  static const List<_CategoryMeta> _categories = [
    _CategoryMeta('general', 'عام', Icons.help_outline, AppColors.navy),
    _CategoryMeta('payment', 'المدفوعات', Icons.payments_outlined,
        AppColors.success),
    _CategoryMeta('service_quality', 'جودة الخدمة', Icons.verified_outlined,
        AppColors.secondary),
    _CategoryMeta('technician', 'الفنيون', Icons.engineering_outlined,
        AppColors.info),
    _CategoryMeta('account', 'الحساب', Icons.person_outline, AppColors.accent),
    _CategoryMeta(
        'complaint', 'شكوى', Icons.report_gmailerrorred_outlined, AppColors.error),
    _CategoryMeta('other', 'أخرى', Icons.more_horiz, AppColors.midGrey),
  ];

  static const List<_PriorityMeta> _priorities = [
    _PriorityMeta('low', 'منخفضة', AppColors.success),
    _PriorityMeta('medium', 'متوسطة', AppColors.warning),
    _PriorityMeta('high', 'عالية', AppColors.error),
  ];

  @override
  void dispose() {
    _subjectCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);

    final now = DateTime.now().toIso8601String();
    final ticketData = <String, dynamic>{
      'customerId': widget.customerId,
      'customerName': widget.customerName,
      'subject': _subjectCtrl.text.trim(),
      'category': _category,
      'priority': _priority,
      'status': 'open',
      'source': 'manual',
      'messages': [
        {
          'senderId': widget.customerId,
          'senderRole': 'customer',
          'senderName': widget.customerName,
          'text': _messageCtrl.text.trim(),
          'attachments': const <String>[],
          'at': now,
        },
      ],
    };

    try {
      await widget.api.createTicket(ticketData);
      if (!mounted) return;
      Navigator.of(context).pop(true);
      SfToast.show(
        context,
        tr(context, 'تم إنشاء التذكرة، سيتواصل معك الدعم قريبًا'),
        tone: SfTone.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _submitting = false);
      SfToast.show(
        context,
        tr(context, 'تعذّر إنشاء التذكرة، حاول مرة أخرى'),
        tone: SfTone.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tr(context, 'تذكرة دعم جديدة'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 19,
              fontWeight: FontWeight.w700,
              color: AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            tr(context, 'صف مشكلتك وسيراجعها فريق الدعم.'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              color: AppColors.midGrey,
            ),
          ),
          const SizedBox(height: 18),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SmartTextField(
                  label: tr(context, 'الموضوع'),
                  hint: tr(context, 'مثال: مشكلة في الدفع'),
                  controller: _subjectCtrl,
                  prefixIcon: Icons.subject,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? tr(context, 'الرجاء كتابة الموضوع')
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  tr(context, 'الفئة'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 9),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((c) {
                    final selected = c.value == _category;
                    return _ChoicePill(
                      label: tr(context, c.label),
                      icon: c.icon,
                      color: c.color,
                      selected: selected,
                      onTap: () => setState(() => _category = c.value),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                Text(
                  tr(context, 'الأولوية'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  children: _priorities.map((p) {
                    final selected = p.value == _priority;
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(end: 8),
                      child: _ChoicePill(
                        label: tr(context, p.label),
                        color: p.color,
                        selected: selected,
                        onTap: () => setState(() => _priority = p.value),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                SmartTextField(
                  label: tr(context, 'الرسالة'),
                  hint: tr(context, 'اشرح المشكلة بالتفصيل…'),
                  controller: _messageCtrl,
                  maxLines: 4,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? tr(context, 'الرجاء كتابة تفاصيل المشكلة')
                      : null,
                ),
                const SizedBox(height: 20),
                SmartButton(
                  label: tr(context, 'إرسال التذكرة'),
                  icon: Icons.send,
                  width: double.infinity,
                  isLoading: _submitting,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Selectable pill used for category / priority choices in the new-ticket
/// sheet.
class _ChoicePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ChoicePill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color.withValues(alpha: 0.12) : AppColors.surfaceVariant,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.4,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected ? color : AppColors.midGrey,
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? color : AppColors.darkGrey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Metadata helpers ───────────────────────────────────────────────

class _CategoryMeta {
  final String value;
  final String label;
  final IconData icon;
  final Color color;
  const _CategoryMeta(this.value, this.label, this.icon, this.color);
}

class _PriorityMeta {
  final String value;
  final String label;
  final Color color;
  const _PriorityMeta(this.value, this.label, this.color);
}

class _StatusMeta {
  final String label;
  final Color color;
  final Color bg;
  const _StatusMeta(this.label, this.color, this.bg);
}

_CategoryMeta _ticketCategoryMeta(String category) {
  switch (category) {
    case 'payment':
      return const _CategoryMeta(
          'payment', 'المدفوعات', Icons.payments_outlined, AppColors.success);
    case 'service_quality':
      return const _CategoryMeta('service_quality', 'جودة الخدمة',
          Icons.verified_outlined, AppColors.secondary);
    case 'technician':
      return const _CategoryMeta(
          'technician', 'الفنيون', Icons.engineering_outlined, AppColors.info);
    case 'account':
      return const _CategoryMeta(
          'account', 'الحساب', Icons.person_outline, AppColors.accent);
    case 'complaint':
      return const _CategoryMeta('complaint', 'شكوى',
          Icons.report_gmailerrorred_outlined, AppColors.error);
    case 'other':
      return const _CategoryMeta(
          'other', 'أخرى', Icons.more_horiz, AppColors.midGrey);
    case 'general':
    default:
      return const _CategoryMeta(
          'general', 'عام', Icons.help_outline, AppColors.navy);
  }
}

_StatusMeta _ticketStatusMeta(String status) {
  switch (status) {
    case 'pending':
      return const _StatusMeta(
          'قيد المراجعة', AppColors.warning, AppColors.warningBg);
    case 'resolved':
      return const _StatusMeta('تم الحل', AppColors.success, AppColors.successBg);
    case 'closed':
      return const _StatusMeta('مغلقة', AppColors.midGrey, AppColors.surfaceVariant);
    case 'open':
    default:
      return const _StatusMeta('مفتوحة', AppColors.info, AppColors.infoBg);
  }
}
