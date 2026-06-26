import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../models/chat_message.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_chat_bubble.dart';
import '../../widgets/sf_states.dart';

class ChatScreen extends StatefulWidget {
  final String issueId;
  final String issueTitle;

  const ChatScreen({
    super.key,
    required this.issueId,
    required this.issueTitle,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _chatService = ChatService();

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final user = context.read<AuthService>().currentUser;
    if (user == null) return;

    _chatService.sendMessage(
      issueId: widget.issueId,
      senderId: user.uid,
      senderName: user.name,
      message: text,
    );

    _messageController.clear();

    // Scroll to bottom
    Future.delayed(const Duration(milliseconds: 200), () {
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
    final period = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.read<AuthService>().currentUser;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Navy hero header: back, avatar, title + subtitle
          SfGradientHeader(
            padding: const EdgeInsetsDirectional.fromSTEB(14, 6, 16, 14),
            bottomRadius: 0,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _HeaderBackButton(onTap: () => Navigator.pop(context)),
                const SizedBox(width: 11),
                _HeaderAvatar(name: widget.issueTitle),
              ],
            ),
            title: widget.issueTitle,
            subtitle: tr(context, 'محادثة البلاغ'),
          ),

          // Messages list
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessages(widget.issueId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return Center(
                    child: SfEmptyState(
                      icon: Icons.chat_bubble_outline_rounded,
                      title: tr(context, 'ابدأ المحادثة'),
                      body: tr(context, 'أرسل رسالة بخصوص هذا البلاغ.'),
                    ),
                  ).animate().fadeIn(duration: 400.ms);
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 16),
                  itemCount: messages.length + 1,
                  itemBuilder: (context, index) {
                    // Leading "Today" date chip
                    if (index == 0) {
                      return _DateChip(label: tr(context, 'اليوم'));
                    }

                    final message = messages[index - 1];
                    final isMe = message.senderId == currentUser?.uid;
                    final showAvatar =
                        index - 1 == 0 ||
                        messages[index - 2].senderId != message.senderId;

                    return SfChatBubble(
                      text: message.message,
                      time: _formatClock(message.timestamp),
                      mine: isMe,
                      senderName: message.senderName,
                      showName: showAvatar,
                    );
                  },
                );
              },
            ),
          ),

          // Message input composer (fixed)
          Container(
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
                      style: GoogleFonts.ibmPlexSansArabic(
                        fontSize: 14,
                        color: AppColors.charcoal,
                      ),
                      decoration: InputDecoration(
                        hintText: tr(context, 'اكتب رسالة…'),
                        hintStyle: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 14,
                          color: AppColors.midGrey,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                _SendButton(onTap: _sendMessage),
              ],
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
          child: Icon(
            Icons.arrow_forward,
            size: 19,
            color: AppColors.white,
          ),
        ),
      ),
    );
  }
}

/// Circular gold-initial avatar shown beside the chat title in the header.
class _HeaderAvatar extends StatelessWidget {
  final String name;

  const _HeaderAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '؟';
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.16),
        shape: BoxShape.circle,
      ),
      child: Text(
        initial,
        style: GoogleFonts.ibmPlexSansArabic(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: AppColors.gold,
        ),
      ),
    );
  }
}

/// Centered pill date separator (e.g. "اليوم").
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

/// Circular heroGradient send button with a soft navy shadow.
/// The glyph mirrors horizontally so it points to the message direction
/// under RTL.
class _SendButton extends StatelessWidget {
  final VoidCallback onTap;

  const _SendButton({required this.onTap});

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
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 46,
            height: 46,
            child: Transform.flip(
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
