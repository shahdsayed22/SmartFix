import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/issue_model.dart';
import '../../widgets/sf_chat_bubble.dart';
import '../../widgets/sf_badges.dart';
import '../../widgets/sf_feedback.dart';
import '../support/ticket_detail_screen.dart';

/// Guided Arabic triage assistant (المساعد الذكي).
///
/// The bot greets the user, asks them to describe their problem, then runs
/// the local NLP mirror [detectCategory] (with [ApiService.classifyText] as a
/// best-effort backend confirmation) to guess the service category + urgency.
/// It builds an editable draft, then creates a support ticket via
/// [ApiService.createTicket] (source: 'chatbot', with seed messages) and opens
/// [TicketDetailScreen] for the newly created ticket.
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

/// One rendered line in the conversation.
class _BotMsg {
  final String text;
  final bool bot;
  final DateTime at;
  _BotMsg(this.text, {required this.bot}) : at = DateTime.now();
}

/// Conversation phase for the guided flow.
enum _Phase { pickIssue, describe, done }

/// Service-category bilingual labels (matches Issue.category snake_case keys).
const Map<String, ({String ar, String en})> _kServiceCats = {
  'plumbing': (ar: 'سباكة', en: 'Plumbing'),
  'electrical': (ar: 'كهرباء', en: 'Electrical'),
  'carpentry': (ar: 'نجارة', en: 'Carpentry'),
  'painting': (ar: 'دهانات', en: 'Painting'),
  'hvac': (ar: 'تكييف وتبريد', en: 'HVAC'),
  'cleaning': (ar: 'تنظيف', en: 'Cleaning'),
  'appliance_repair': (ar: 'إصلاح أجهزة', en: 'Appliance Repair'),
  'welding': (ar: 'لحام', en: 'Welding'),
  'tiling': (ar: 'بلاط', en: 'Tiling'),
};

String _serviceCatLabel(String? key, bool isEn) {
  final c = _kServiceCats[key];
  if (c == null) return isEn ? 'General' : 'عام';
  return isEn ? c.en : c.ar;
}

/// The triage draft the bot assembles before creating a ticket.
class _Draft {
  final String categoryKey; // VALID support-ticket category (e.g. 'payment')
  final String categoryLabel; // localized display label
  final IconData icon;
  final IssueUrgency urgency;
  final String subject;
  final String description;
  // Linked service request (set when the customer picked one of their issues).
  final String? issueId;
  final String? issueNumber;
  final String? technicianId;
  final String? technicianName;
  const _Draft({
    required this.categoryKey,
    required this.categoryLabel,
    required this.icon,
    required this.urgency,
    required this.subject,
    required this.description,
    this.issueId,
    this.issueNumber,
    this.technicianId,
    this.technicianName,
  });
}

/// Bilingual starter prompts — support problems (not just service requests).
const List<({String ar, String en})> _kSuggestions = [
  (ar: 'عندي مشكلة في الدفع', en: 'I have a payment problem'),
  (ar: 'أريد استرداد مبلغ', en: 'I want a refund'),
  (ar: 'الفني لم يحضر', en: "The technician didn't show up"),
  (ar: 'مشكلة في حسابي', en: 'A problem with my account'),
  (ar: 'لدي شكوى على الخدمة', en: 'I have a complaint about the service'),
];

class _ChatbotScreenState extends State<ChatbotScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<_BotMsg> _msgs = [];
  _Draft? _draft;
  bool _typing = false;
  bool _emergency = false;
  bool _submitting = false;

  // --- Guided flow: pick a request → describe → done ---
  _Phase _phase = _Phase.pickIssue;
  List<Map<String, dynamic>> _issues = [];
  bool _loadingIssues = false;
  Map<String, dynamic>? _selectedIssue;
  String _createdTicketId = '';

  bool _isEn(BuildContext context) {
    try {
      return context.read<LocaleProvider>().isEn;
    } catch (_) {
      return false;
    }
  }

  String _greeting(bool isEn) => isEn
      ? "Hi! I'm the SmartFix smart assistant. Which of your requests are you "
          'having a problem with? Pick it below, or just describe your problem.'
      : 'مرحبًا! أنا مساعد سمارت فيكس الذكي. في أي طلب من طلباتك تواجه مشكلة؟ '
          'اختر الطلب من الأسفل، أو صِف مشكلتك مباشرةً.';

  /// Classify a free-text problem into a VALID support-ticket category (matches
  /// the Ticket schema enum) with a bilingual label + icon. A payment/account/
  /// complaint problem must NOT be forced into a service category like HVAC.
  ({String key, String labelAr, String labelEn, IconData icon}) _supportCategory(
      String text) {
    final t = text.toLowerCase();
    bool has(List<String> ws) => ws.any((w) => t.contains(w));
    if (has([
      'دفع', 'الدفع', 'مدفع', 'فلوس', 'فلوسي', 'فاتور', 'استرداد', 'استرجاع',
      'رصيد', 'تحويل', 'بطاقة', 'فيزا', 'محفظة', 'اتخصم', 'خصم', 'paymob',
      'payment', 'refund', 'invoice', 'money', 'charged', 'paid', 'wallet', 'fawry', 'visa',
    ])) {
      return (key: 'payment', labelAr: 'الدفع', labelEn: 'Payment', icon: Icons.payments_outlined);
    }
    if (has([
      'حساب', 'حسابي', 'كلمة المرور', 'كلمه السر', 'الايميل', 'البريد', 'تسجيل الدخول',
      'نسيت', 'login', 'log in', 'password', 'account', 'sign in', 'email', 'register',
    ])) {
      return (key: 'account', labelAr: 'الحساب', labelEn: 'Account', icon: Icons.person_outline);
    }
    if (has([
      'الفني', 'الفنى', 'الفنيين', 'المهندس', 'الصنايعي', 'technician', 'worker',
      'craftsman', 'لم يحضر', 'مش جه', 'ما جاش', 'اتأخر', 'no show', 'late',
    ])) {
      return (key: 'technician', labelAr: 'الفني', labelEn: 'Technician', icon: Icons.handyman_outlined);
    }
    if (has([
      'شكوى', 'شكوي', 'اشتكي', 'مش راضي', 'مش عاجبني', 'زعلان', 'سيئة', 'سيء',
      'وحش', 'زفت', 'رديء', 'complaint', 'complain', 'bad', 'poor', 'not satisfied', 'unhappy',
    ])) {
      return (key: 'complaint', labelAr: 'شكوى', labelEn: 'Complaint', icon: Icons.report_problem_outlined);
    }
    if (has([
      'جودة', 'الخدمة سيئة', 'الشغل وحش', 'شغل مش كويس', 'اعادة العمل',
      'quality', 'service quality', 'redo',
    ])) {
      return (key: 'service_quality', labelAr: 'جودة الخدمة', labelEn: 'Service Quality', icon: Icons.thumb_up_alt_outlined);
    }
    return (key: 'general', labelAr: 'عام', labelEn: 'General', icon: Icons.help_outline);
  }

  @override
  void initState() {
    super.initState();
    _msgs.add(_BotMsg(_greeting(_isEn(context)), bot: true));
    _loadIssues();
  }

  /// Load the signed-in customer's requests so they can pick the one they have
  /// a problem with. Each request carries its category + assigned worker, which
  /// we wire onto the ticket so support (and the worker) get the full context.
  Future<void> _loadIssues() async {
    final auth = context.read<AuthService>();
    final uid = auth.currentUser?.uid ?? auth.uid ?? '';
    if (uid.isEmpty) return; // guest — fall back to free-text only
    setState(() => _loadingIssues = true);
    try {
      final list = await _api.getIssues(customerId: uid, limit: 50);
      if (!mounted) return;
      setState(() => _issues = list);
    } catch (_) {
      // backend unreachable → free-text flow still works
    } finally {
      if (mounted) setState(() => _loadingIssues = false);
    }
  }

  /// The customer tapped one of their requests. Confirm its category + assigned
  /// worker, then ask them to describe the problem.
  void _pickIssue(Map<String, dynamic> issue) {
    final isEn = _isEn(context);
    final num = (issue['issueNumber'] ?? '').toString();
    final catLabel = _serviceCatLabel(issue['category']?.toString(), isEn);
    final worker = (issue['assignedTechnicianName'] ?? '').toString();
    setState(() {
      _selectedIssue = issue;
      _phase = _Phase.describe;
      _msgs.add(_BotMsg(
        isEn ? 'My problem is with request $num' : 'مشكلتي في الطلب $num',
        bot: false,
      ));
      _msgs.add(_BotMsg(
        worker.isNotEmpty
            ? (isEn
                ? 'This request ($num) is in “$catLabel”, assigned to $worker. '
                    'Tell me briefly what went wrong and I\'ll reach out to $worker for you.'
                : 'هذا الطلب ($num) في فئة «$catLabel» ومُسند إلى $worker. '
                    'أخبرني باختصار ماذا حدث وسأتواصل مع $worker نيابةً عنك.')
            : (isEn
                ? 'This request ($num) is in “$catLabel” and has no assigned '
                    'worker yet. Describe the problem and I\'ll open a support ticket.'
                : 'هذا الطلب ($num) في فئة «$catLabel» وغير مُسند لأي فني بعد. '
                    'صِف المشكلة وسأفتح لك تذكرة دعم.'),
        bot: true,
      ));
    });
    _scrollToEnd();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _api.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Local urgency guess — OFFLINE fallback only (the server's full Arabic
  /// severity lexicon is preferred when reachable, see _handle).
  IssueUrgency _guessUrgency(String text) {
    final emergency = RegExp('طارئ|خطر|حريق|شرر|احتراق|انفجار|غاز|تسرب غاز');
    final high = RegExp('عاجل|اليوم|بسرعة|بسرعه|فورا|فورًا|حالا|حالًا|مكسور|مش شغال|تسريب');
    if (emergency.hasMatch(text)) return IssueUrgency.emergency;
    if (high.hasMatch(text)) return IssueUrgency.high;
    return IssueUrgency.medium;
  }

  /// Map a server urgency key ('low'|'medium'|'high'|'emergency') to the enum.
  IssueUrgency? _urgencyFromKey(String? key) {
    if (key == null) return null;
    for (final u in IssueUrgency.values) {
      if (u.name == key) return u;
    }
    return null;
  }

  String _clock(DateTime at) {
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    final period =
        at.hour < 12 ? tr(context, 'ص') : tr(context, 'م');
    return '$h:$m $period';
  }

  Future<void> _handle(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _typing || _submitting) return;

    setState(() {
      _msgs.add(_BotMsg(text, bot: false));
      _controller.clear();
      _typing = true;
    });
    _scrollToEnd();

    // Capture the active language up front (context is safe to read here).
    final isEn = _isEn(context);

    // Classify into a VALID support category (payment/account/complaint/…),
    // never a service category — a payment problem must not become "HVAC".
    final cat = _supportCategory(text);

    // Best-effort backend URGENCY only — the model's category is irrelevant to
    // a support ticket and is intentionally ignored here.
    String? remoteUrgency;
    try {
      final remote = await _api.classifyText(text);
      final ru = remote['urgency'];
      if (ru is String && ru.isNotEmpty) remoteUrgency = ru;
    } catch (_) {
      // offline / backend down → fall back to the local guess
    }

    final urgency = _urgencyFromKey(remoteUrgency) ?? _guessUrgency(text);
    final catLabel = isEn ? cat.labelEn : cat.labelAr;
    final urgLabel = isEn ? _urgencyLabelEn(urgency) : _urgencyLabel(urgency);
    final subject =
        text.characters.length > 40 ? '${text.characters.take(40)}…' : text;

    if (!mounted) return;
    setState(() {
      _typing = false;
      _emergency = _emergency || urgency == IssueUrgency.emergency;
      _msgs.add(
        _BotMsg(
          isEn
              ? 'Got it 👍 your issue looks related to “$catLabel” with “$urgLabel” '
                  'priority. I’ve drafted a support ticket — review it and send.'
              : 'فهمت 👍 يبدو أن مشكلتك متعلقة بـ «$catLabel» وبأولوية «$urgLabel». '
                  'جهّزت لك مسودة تذكرة دعم — راجعها ثم أرسلها.',
          bot: true,
        ),
      );
      final iss = _selectedIssue;
      _draft = _Draft(
        categoryKey: cat.key,
        categoryLabel: catLabel,
        icon: cat.icon,
        urgency: urgency,
        subject: subject,
        description: text,
        issueId: iss?['_id']?.toString(),
        issueNumber: iss?['issueNumber']?.toString(),
        technicianId: iss?['assignedTechnicianId']?.toString(),
        technicianName: iss?['assignedTechnicianName']?.toString(),
      );
    });
    _scrollToEnd();
  }

  String _urgencyLabelEn(IssueUrgency u) {
    switch (u) {
      case IssueUrgency.low:
        return 'Low';
      case IssueUrgency.medium:
        return 'Medium';
      case IssueUrgency.high:
        return 'High';
      case IssueUrgency.emergency:
        return 'Emergency';
    }
  }

  String _urgencyLabel(IssueUrgency u) {
    switch (u) {
      case IssueUrgency.low:
        return 'منخفضة';
      case IssueUrgency.medium:
        return 'متوسطة';
      case IssueUrgency.high:
        return 'عالية';
      case IssueUrgency.emergency:
        return 'طارئة';
    }
  }

  /// Map urgency → Ticket priority enum (low | medium | high).
  String _priorityOf(IssueUrgency u) {
    switch (u) {
      case IssueUrgency.low:
        return 'low';
      case IssueUrgency.medium:
        return 'medium';
      case IssueUrgency.high:
      case IssueUrgency.emergency:
        return 'high';
    }
  }

  Future<void> _submit() async {
    final draft = _draft;
    if (draft == null || _submitting) return;

    final isEn = _isEn(context);
    final user = context.read<AuthService>().currentUser;
    final uid = user?.uid ?? context.read<AuthService>().uid ?? '';
    final name = user?.name ?? '';
    final catLabel = draft.categoryLabel;
    final hasWorker = (draft.technicianId ?? '').isNotEmpty;
    final workerName = draft.technicianName ?? '';

    setState(() => _submitting = true);

    try {
      final now = DateTime.now().toIso8601String();

      // Bot summary line (bilingual).
      final botSummary = isEn
          ? 'Ticket from the smart assistant — category: $catLabel · priority: '
              '${_urgencyLabelEn(draft.urgency)}'
              '${draft.issueNumber != null ? ' · request ${draft.issueNumber}' : ''}.'
          : 'تذكرة من المساعد الذكي — الفئة: $catLabel · الأولوية: '
              '${_urgencyLabel(draft.urgency)}'
              '${draft.issueNumber != null ? ' · الطلب ${draft.issueNumber}' : ''}.';

      final messages = <Map<String, dynamic>>[
        {
          'senderId': 'bot',
          'senderRole': 'bot',
          'senderName': isEn ? 'Smart Assistant' : 'المساعد الذكي',
          'text': botSummary,
          'at': now,
        },
        {
          'senderId': uid,
          'senderRole': 'customer',
          'senderName': name,
          'text': draft.description,
          'at': now,
        },
      ];

      // If a worker is assigned, record (in the thread) that we're asking them
      // what happened. The backend also pushes them a notification.
      if (hasWorker) {
        messages.add({
          'senderId': 'bot',
          'senderRole': 'bot',
          'senderName': isEn ? 'Smart Assistant' : 'المساعد الذكي',
          'text': isEn
              ? 'We have asked $workerName (assigned to request '
                  '${draft.issueNumber ?? ''}) to explain what happened.'
              : 'تواصلنا مع $workerName (المسؤول عن الطلب '
                  '${draft.issueNumber ?? ''}) لمعرفة ما حدث.',
          'at': now,
        });
      }

      final result = await _api.createTicket({
        'customerId': uid,
        'customerName': name,
        'subject': draft.subject,
        'category': draft.categoryKey.isNotEmpty ? draft.categoryKey : 'general',
        'status': 'open',
        'priority': _priorityOf(draft.urgency),
        'source': 'chatbot',
        if ((draft.issueId ?? '').isNotEmpty) 'relatedIssueId': draft.issueId,
        if ((draft.issueNumber ?? '').isNotEmpty)
          'relatedIssueNumber': draft.issueNumber,
        if (hasWorker) 'technicianId': draft.technicianId,
        if (workerName.isNotEmpty) 'technicianName': workerName,
        'messages': messages,
      });

      if (!mounted) return;
      final newId = (result['_id'] ?? result['id'] ?? '').toString();
      if (newId.isEmpty) {
        throw Exception('missing ticket id');
      }

      // Stay in the chat and confirm — the customer asked to be contacted later.
      setState(() {
        _submitting = false;
        _draft = null;
        _phase = _Phase.done;
        _createdTicketId = newId;
        _msgs.add(_BotMsg(
          hasWorker
              ? (isEn
                  ? 'Done ✅ We\'ve logged your problem and contacted $workerName '
                      'about it. We\'ll get back to you after it\'s resolved.'
                  : 'تم ✅ سجّلنا مشكلتك وتواصلنا مع $workerName بشأنها. '
                      'سنعاود التواصل معك بعد حلّها.')
              : (isEn
                  ? 'Done ✅ We\'ve logged your problem with support. '
                      'We\'ll get back to you after it\'s resolved.'
                  : 'تم ✅ سجّلنا مشكلتك لدى الدعم. سنعاود التواصل معك بعد حلّها.'),
          bot: true,
        ));
      });
      _scrollToEnd();
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
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: ListView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 16),
              children: [
                if (_emergency) _buildEmergencyCard(context),
                ..._buildMessages(context),
                if (_typing) _buildTyping(),
                if (_draft != null) _buildDraftCard(context, _draft!),
                if (_phase == _Phase.pickIssue && _draft == null && !_typing)
                  _buildIssuePicker(context),
                if (_phase == _Phase.done && _createdTicketId.isNotEmpty)
                  _buildViewTicketButton(context),
              ],
            ),
          ),
          _buildComposer(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 14),
            child: Row(
              children: [
                Material(
                  color: AppColors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(12),
                    child: const SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.arrow_back,
                        size: 19,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 21,
                    color: AppColors.gold,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(context, 'المساعد الذكي'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              color: Color(0xFF5FE08A),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            tr(context, 'متصل الآن'),
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 11.5,
                              color: AppColors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMessages(BuildContext context) {
    return [
      for (final m in _msgs)
        SfChatBubble(
          text: m.text,
          time: _clock(m.at),
          // The user's own messages sit on the trailing (navy) side.
          mine: !m.bot,
          senderName: m.bot ? tr(context, 'المساعد الذكي') : '',
          showName: m.bot,
        ),
    ];
  }

  Widget _buildTyping() {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 10, start: 36),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: AppColors.surface,
            border: Border.all(color: AppColors.lineSoft),
            borderRadius: const BorderRadiusDirectional.only(
              topStart: Radius.circular(18),
              topEnd: Radius.circular(18),
              bottomStart: Radius.circular(5),
              bottomEnd: Radius.circular(18),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(
              3,
              (i) => Padding(
                padding: EdgeInsetsDirectional.only(start: i == 0 ? 0 : 4),
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: const BoxDecoration(
                    color: AppColors.midGrey,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyCard(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.dangerBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.emergency_share,
            size: 20,
            color: AppColors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(context, 'حالة طارئة محتملة'),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  tr(
                    context,
                    'سلامتك أولًا — لمشاكل الغاز أو الكهرباء الخطيرة اتصل بالطوارئ',
                  ),
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12,
                    height: 1.6,
                    color: AppColors.darkGrey,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftCard(BuildContext context, _Draft draft) {
    return Container(
      margin: const EdgeInsetsDirectional.only(top: 4, bottom: 6),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppColors.rCard),
        border: Border.all(color: AppColors.navy, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 22,
            spreadRadius: -10,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.description_outlined,
                size: 17,
                color: AppColors.navy,
              ),
              const SizedBox(width: 8),
              Text(
                tr(context, 'مسودة تذكرة الدعم'),
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.charcoal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.navySoft,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(draft.icon, size: 20, color: AppColors.navy),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.categoryLabel,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      draft.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 12,
                        color: AppColors.midGrey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SfUrgencyPill(draft.urgency),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: _submitButton(context),
          ),
        ],
      ),
    );
  }

  Widget _submitButton(BuildContext context) {
    return GestureDetector(
      onTap: _submitting ? null : _submit,
      child: Container(
        height: 50,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppColors.navy,
          borderRadius: BorderRadius.circular(AppColors.rBtn),
          boxShadow: const [
            BoxShadow(
              color: AppColors.navyShadow,
              blurRadius: 16,
              spreadRadius: -6,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child:
            _submitting
                ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor:
                        AlwaysStoppedAnimation<Color>(AppColors.white),
                  ),
                )
                : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr(context, 'إنشاء تذكرة الدعم'),
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.white,
                      ),
                    ),
                    const SizedBox(width: 9),
                    const Icon(
                      Icons.arrow_back,
                      size: 19,
                      color: AppColors.white,
                    ),
                  ],
                ),
      ),
    );
  }

  /// Lets the customer pick which of their requests has a problem. Each card
  /// shows the request number, its service category and the assigned worker.
  /// Falls back to the free-text suggestion chips when there are no requests.
  Widget _buildIssuePicker(BuildContext context) {
    final isEn = _isEn(context);
    if (_loadingIssues) {
      return const Padding(
        padding: EdgeInsetsDirectional.only(top: 10, start: 36),
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4),
        ),
      );
    }
    if (_issues.isEmpty) return _buildSuggestions(context);

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, start: 8, end: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final issue in _issues) _buildIssueOption(context, issue, isEn),
          const SizedBox(height: 6),
          Text(
            isEn
                ? 'Or just type your problem below.'
                : 'أو اكتب مشكلتك في الأسفل.',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11.5,
              color: AppColors.midGrey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueOption(
      BuildContext context, Map<String, dynamic> issue, bool isEn) {
    final num = (issue['issueNumber'] ?? '').toString();
    final title = (issue['title'] ?? '').toString();
    final catLabel = _serviceCatLabel(issue['category']?.toString(), isEn);
    final worker = (issue['assignedTechnicianName'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => _pickIssue(issue),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.line),
            ),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.navySoft,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.receipt_long_outlined,
                      size: 19, color: AppColors.navy),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        num.isNotEmpty ? '$num · $catLabel' : catLabel,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        worker.isNotEmpty
                            ? (isEn ? 'Worker: $worker' : 'الفني: $worker')
                            : (title.isNotEmpty
                                ? title
                                : (isEn ? 'No worker yet' : 'بدون فني بعد')),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          color: AppColors.midGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 20, color: AppColors.midGrey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildViewTicketButton(BuildContext context) {
    final isEn = _isEn(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 10, bottom: 4),
      child: GestureDetector(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => TicketDetailScreen(ticketId: _createdTicketId),
            ),
          );
        },
        child: Container(
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(AppColors.rBtn),
            border: Border.all(color: AppColors.navy, width: 1.4),
          ),
          child: Text(
            isEn ? 'View ticket' : 'عرض التذكرة',
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.navy,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    final isEn = _isEn(context);
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, start: 36),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in _kSuggestions)
            GestureDetector(
              onTap: () => _handle(isEn ? s.en : s.ar),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  isEn ? s.en : s.ar,
                  style: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: AppColors.navy,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildComposer(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 10, 14, 12),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(22),
                  ),
                  padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
                  child: TextField(
                    controller: _controller,
                    textAlign: TextAlign.start,
                    textInputAction: TextInputAction.send,
                    minLines: 1,
                    maxLines: 4,
                    enabled: !_submitting,
                    onSubmitted: _handle,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 14,
                      color: AppColors.charcoal,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      contentPadding:
                          const EdgeInsets.symmetric(vertical: 12),
                      hintText: tr(context, 'صِف مشكلتك…'),
                      hintStyle: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        color: AppColors.midGrey,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              GestureDetector(
                onTap:
                    (_typing || _submitting)
                        ? null
                        : () => _handle(_controller.text),
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.heroGradient,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: AppColors.navyShadow,
                        blurRadius: 14,
                        spreadRadius: -6,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Transform.flip(
                    flipX: true,
                    child: const Icon(
                      Icons.send,
                      size: 20,
                      color: AppColors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
