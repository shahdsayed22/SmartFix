import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../models/ticket.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_chat_bubble.dart';
import '../../widgets/sf_states.dart';

/// Support ticket conversation. Loads a single [Ticket] by id and renders its
/// embedded `messages` thread (customer / admin / bot) using [SfChatBubble],
/// aligned by `senderRole` (the customer's own messages on the start side).
/// A composer appends a reply via [ApiService.replyTicket] and refreshes the
/// thread in place. Read-only otherwise — nothing destructive.
class TicketDetailScreen extends StatefulWidget {
  final String ticketId;

  const TicketDetailScreen({super.key, required this.ticketId});

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final _api = ApiService();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();

  Ticket? _ticket;
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _api.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = Ticket.fromJson(data);
        _loading = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = tr(context, 'تعذّر تحميل التذكرة. حاول مرة أخرى.');
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    final ticket = _ticket;
    if (ticket == null) return;

    final user = context.read<AuthService>().currentUser;

    setState(() => _sending = true);
    try {
      final data = await _api.replyTicket(widget.ticketId, {
        'senderId': user?.uid ?? ticket.customerId,
        'senderRole': 'customer',
        'senderName': user?.name ?? ticket.customerName,
        'text': text,
      });
      if (!mounted) return;
      _messageController.clear();
      setState(() {
        _ticket = Ticket.fromJson(data);
        _sending = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(context, 'تعذّر إرسال الرسالة.'))),
      );
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 220), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatClock(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.hour < 12 ? tr(context, 'ص') : tr(context, 'م');
    return '$h:$m $period';
  }

  // Localized Arabic label for a ticket status.
  String _statusLabel(String status) {
    switch (status) {
      case 'open':
        return tr(context, 'مفتوحة');
      case 'pending':
        return tr(context, 'قيد المعالجة');
      case 'resolved':
        return tr(context, 'تم الحل');
      case 'closed':
        return tr(context, 'مغلقة');
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'open':
        return AppColors.info;
      case 'pending':
        return AppColors.warning;
      case 'resolved':
        return AppColors.success;
      case 'closed':
        return AppColors.midGrey;
      default:
        return AppColors.midGrey;
    }
  }

  // Arabic label for a sender role shown above non-customer bubbles.
  String _roleLabel(TicketMessage m) {
    if (m.senderRole == 'admin') return tr(context, 'الدعم الفني');
    if (m.senderRole == 'bot') return tr(context, 'المساعد الذكي');
    return m.senderName.isNotEmpty ? m.senderName : tr(context, 'أنت');
  }

  bool get _isClosed =>
      _ticket?.status == 'closed' || _ticket?.status == 'resolved';

  @override
  Widget build(BuildContext context) {
    final ticket = _ticket;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SfGradientHeader(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 16, 16),
            bottomRadius: 0,
            leading: _HeaderBackButton(onTap: () => Navigator.pop(context)),
            title: ticket?.subject.isNotEmpty == true
                ? ticket!.subject
                : tr(context, 'تفاصيل التذكرة'),
            subtitle: ticket != null && ticket.ticketId.isNotEmpty
                ? '${tr(context, 'رقم التذكرة')}: ${ticket.ticketId}'
                : tr(context, 'الدعم الفني'),
            actions: [
              if (ticket != null) _StatusChip(
                label: _statusLabel(ticket.status),
                color: _statusColor(ticket.status),
              ),
            ],
          ),
          Expanded(child: _buildBody()),
          if (ticket != null && !_isClosed) _buildComposer(),
          if (ticket != null && _isClosed) _buildClosedBanner(),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 16),
        children: const [
          SfSkeletonCard(),
          SfSkeletonCard(),
          SfSkeletonCard(),
        ],
      );
    }

    if (_error != null) {
      return SfEmptyState(
        icon: Icons.cloud_off_rounded,
        title: tr(context, 'حدث خطأ'),
        body: _error!,
        action: TextButton(
          onPressed: _load,
          child: Text(
            tr(context, 'إعادة المحاولة'),
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ),
      );
    }

    final messages = _ticket?.messages ?? const <TicketMessage>[];

    if (messages.isEmpty) {
      return SfEmptyState(
        icon: Icons.chat_bubble_outline_rounded,
        title: tr(context, 'لا توجد رسائل بعد'),
        body: tr(context, 'ابدأ المحادثة مع فريق الدعم بكتابة رسالتك.'),
      ).animate().fadeIn(duration: 350.ms);
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _load,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 16),
        itemCount: messages.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _DateChip(label: tr(context, 'المحادثة'));
          }
          final i = index - 1;
          final message = messages[i];
          // Customer's own messages render as "mine" (start side, navy);
          // admin/bot render as the other party (white, with avatar/name).
          final mine = message.senderRole == 'customer';
          final showName = i == 0 ||
              messages[i - 1].senderRole != message.senderRole;

          return SfChatBubble(
            text: message.text,
            time: _formatClock(message.at),
            mine: mine,
            senderName: _roleLabel(message),
            showName: showName,
          );
        },
      ),
    );
  }

  Widget _buildComposer() {
    return Container(
      padding: EdgeInsetsDirectional.only(
        start: 14,
        end: 14,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
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
                controller: _messageController,
                textAlign: TextAlign.start,
                minLines: 1,
                maxLines: 4,
                enabled: !_sending,
                style: GoogleFonts.ibmPlexSansArabic(
                  fontSize: 14,
                  color: AppColors.charcoal,
                ),
                decoration: InputDecoration(
                  hintText: tr(context, 'اكتب ردك…'),
                  hintStyle: GoogleFonts.ibmPlexSansArabic(
                    fontSize: 14,
                    color: AppColors.midGrey,
                  ),
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _send(),
              ),
            ),
          ),
          const SizedBox(width: 9),
          _SendButton(onTap: _send, busy: _sending),
        ],
      ),
    );
  }

  Widget _buildClosedBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsetsDirectional.only(
        start: 16,
        end: 16,
        top: 14,
        bottom: MediaQuery.of(context).padding.bottom + 14,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.lineSoft)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline_rounded,
              size: 16, color: AppColors.midGrey),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              tr(context, 'تم إغلاق هذه التذكرة. لا يمكن إرسال ردود جديدة.'),
              textAlign: TextAlign.center,
              style: GoogleFonts.ibmPlexSansArabic(
                fontSize: 13,
                color: AppColors.midGrey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded back button matching the prototype's header chip.
class _HeaderBackButton extends StatelessWidget {
  final VoidCallback onTap;

  const _HeaderBackButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.white.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: const SizedBox(
          width: 38,
          height: 38,
          child: Icon(Icons.arrow_forward, size: 19, color: AppColors.white),
        ),
      ),
    );
  }
}

/// Translucent status chip rendered on the header (e.g. "مفتوحة").
class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(11, 5, 11, 5),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.white,
            ),
          ),
        ],
      ),
    );
  }
}

/// Centered pill date/section separator.
class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.only(bottom: 14),
      child: Center(
        child: Container(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 11,
              color: AppColors.midGrey,
            ),
          ),
        ),
      ),
    );
  }
}

/// Circular heroGradient send button with a soft navy shadow. Shows a spinner
/// while a reply is in flight; the glyph mirrors under RTL.
class _SendButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool busy;

  const _SendButton({required this.onTap, required this.busy});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 14,
            spreadRadius: -6,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: busy ? null : onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 46,
            height: 46,
            child: busy
                ? const Padding(
                    padding: EdgeInsets.all(13),
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: AppColors.white,
                    ),
                  )
                : Transform.flip(
                    flipX: Directionality.of(context) == TextDirection.rtl,
                    child: const Icon(
                      Icons.send_rounded,
                      color: AppColors.white,
                      size: 20,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
