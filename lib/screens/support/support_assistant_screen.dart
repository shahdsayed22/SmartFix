import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../l10n/locale_provider.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../../widgets/sf_chat_bubble.dart';
import '../../widgets/sf_feedback.dart';
import 'ticket_detail_screen.dart';

/// Bilingual SUPPORT assistant (مساعد الدعم) — distinct from the triage bot.
///
/// Answers operational questions about jobs, payments/Paymob, and (for workers)
/// wallet/earnings & verification, grounded in the user's live data via
/// [ApiService.supportChat]. Escalates to a human support ticket when needed.
class SupportAssistantScreen extends StatefulWidget {
  /// 'customer' | 'worker'. Defaults from the signed-in user's role.
  final String? role;

  /// Optional context so the assistant is pre-grounded on a specific job/payment.
  final String? issueId;
  final String? paymentId;

  const SupportAssistantScreen({
    super.key,
    this.role,
    this.issueId,
    this.paymentId,
  });

  @override
  State<SupportAssistantScreen> createState() => _SupportAssistantScreenState();
}

class _Msg {
  final String text;
  final bool bot;
  final DateTime at;
  _Msg(this.text, {required this.bot}) : at = DateTime.now();
}

class _SupportAssistantScreenState extends State<SupportAssistantScreen> {
  final ApiService _api = ApiService();
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scroll = ScrollController();

  final List<_Msg> _msgs = [];
  List<String> _suggestions = const [];
  bool _typing = false;

  // Last escalation (shown as a "View ticket" action for logged-in users).
  String? _ticketMongoId;
  // Human-readable number (TKT-XXXX) of the last escalation, shown to the user.
  String? _ticketNumber;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _api.dispose();
    super.dispose();
  }

  String get _role {
    if (widget.role != null) return widget.role!;
    final r = context.read<AuthService>().currentUser?.role;
    return r == UserRole.worker ? 'worker' : 'customer';
  }

  String get _lang => context.read<LocaleProvider>().isEn ? 'en' : 'ar';

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

  String _clock(DateTime at) {
    final h = at.hour % 12 == 0 ? 12 : at.hour % 12;
    final m = at.minute.toString().padLeft(2, '0');
    final period = at.hour < 12 ? tr(context, 'ص') : tr(context, 'م');
    return '$h:$m $period';
  }

  /// Greet via the server (empty transcript) so the welcome + suggestions are
  /// localized and role-aware. Falls back to a local greeting if offline.
  Future<void> _bootstrap() async {
    setState(() => _typing = true);
    try {
      final res = await _send(const []);
      if (!mounted) return;
      setState(() {
        _typing = false;
        _msgs.add(_Msg(res['reply']?.toString() ?? '', bot: true));
        _suggestions = _readSuggestions(res);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _msgs.add(_Msg(
          tr(context, 'مرحبًا! أنا مساعد دعم سمارت فيكس. كيف أقدر أساعدك؟'),
          bot: true,
        ));
      });
    }
    _scrollToEnd();
  }

  List<String> _readSuggestions(Map<String, dynamic> res) {
    final s = res['suggestions'];
    if (s is List) return s.map((e) => e.toString()).toList();
    return const [];
  }

  /// POST the current transcript (+ optional extra user text already appended).
  Future<Map<String, dynamic>> _send(List<_Msg> history) {
    final auth = context.read<AuthService>();
    final messages = history
        .map((m) => {'role': m.bot ? 'assistant' : 'user', 'text': m.text})
        .toList();
    return _api.supportChat(
      messages: messages,
      lang: _lang,
      role: _role,
      userId: auth.uid ?? '',
      userName: auth.currentUser?.name ?? '',
      issueId: widget.issueId,
      paymentId: widget.paymentId,
    );
  }

  Future<void> _handle(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _typing) return;

    setState(() {
      _msgs.add(_Msg(text, bot: false));
      _controller.clear();
      _suggestions = const [];
      _typing = true;
    });
    _scrollToEnd();

    try {
      final res = await _send(_msgs);
      if (!mounted) return;
      setState(() {
        _typing = false;
        _msgs.add(_Msg(res['reply']?.toString() ?? '', bot: true));
        _suggestions = _readSuggestions(res);
      });

      final esc = res['escalation'];
      if (esc is Map && esc['created'] == true) {
        _ticketMongoId = (esc['_id'] ?? '').toString();
        _ticketNumber = (esc['ticketId'] ?? '').toString();
        if (mounted) {
          final num = _ticketNumber ?? '';
          SfToast.show(
            context,
            num.isNotEmpty
                ? '${tr(context, 'تم تحويلك إلى فريق الدعم')} · $num'
                : tr(context, 'تم تحويلك إلى فريق الدعم'),
            tone: SfTone.success,
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _typing = false;
        _msgs.add(_Msg(
          tr(context, 'تعذّر الاتصال بمساعد الدعم، حاول مرة أخرى.'),
          bot: true,
        ));
      });
    }
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final showViewTicket = _ticketMongoId != null &&
        _ticketMongoId!.isNotEmpty &&
        !context.read<AuthService>().isGuest;

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
                for (final m in _msgs)
                  SfChatBubble(
                    text: m.text,
                    time: _clock(m.at),
                    mine: !m.bot,
                    senderName: m.bot ? tr(context, 'مساعد الدعم') : '',
                    showName: m.bot,
                  ),
                if (_typing) _buildTyping(),
                if (showViewTicket) _buildViewTicket(context),
                if (_suggestions.isNotEmpty && !_typing)
                  _buildSuggestions(context),
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
                      child: Icon(Icons.arrow_back,
                          size: 19, color: AppColors.white),
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
                  child: const Icon(Icons.support_agent_rounded,
                      size: 22, color: AppColors.white),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(context, 'مساعد الدعم'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tr(context, 'دعم الطلبات والدفع على مدار الساعة'),
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11.5,
                          color: AppColors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
                // Quick AR/EN switch right in the chat.
                Material(
                  color: AppColors.white.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => context.read<LocaleProvider>().toggle(),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.translate_rounded,
                              size: 16, color: AppColors.white),
                          const SizedBox(width: 5),
                          Text(
                            context.watch<LocaleProvider>().isEn ? 'ع' : 'EN',
                            style: GoogleFonts.ibmPlexSansArabic(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
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

  Widget _buildViewTicket(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 4, bottom: 8, start: 36),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: OutlinedButton.icon(
          onPressed: () {
            final id = _ticketMongoId;
            if (id == null || id.isEmpty) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => TicketDetailScreen(ticketId: id),
              ),
            );
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.line),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          icon: const Icon(Icons.confirmation_number_outlined, size: 17),
          label: Text(
            _ticketNumber != null && _ticketNumber!.isNotEmpty
                ? '${tr(context, 'عرض التذكرة')} · ${_ticketNumber!}'
                : tr(context, 'عرض التذكرة'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestions(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6, start: 36),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final s in _suggestions)
            GestureDetector(
              onTap: () => _handle(s),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.line),
                ),
                child: Text(
                  s,
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
                    enabled: !_typing,
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
                      hintText: tr(context, 'اكتب سؤالك…'),
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
                onTap: _typing ? null : () => _handle(_controller.text),
                child: Container(
                  width: 46,
                  height: 46,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    gradient: AppColors.heroGradient,
                    shape: BoxShape.circle,
                  ),
                  child: Transform.flip(
                    flipX: true,
                    child: const Icon(Icons.send,
                        size: 20, color: AppColors.white),
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
