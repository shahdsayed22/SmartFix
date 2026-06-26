import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../services/job_service.dart';
import '../../services/chat_service.dart';
import '../../models/issue_model.dart';
import '../../models/user_model.dart';
import '../../models/chat_message.dart';
import '../../widgets/sf_header.dart';
import '../../widgets/sf_states.dart';
import '../../widgets/sf_avatar.dart';
import '../../widgets/sf_icons.dart';
import 'chat_screen.dart';

/// Real conversation list. Derives conversations from the user's issues that
/// have a counterpart (customer ⇄ assigned technician) and opens the live
/// Firestore-backed [ChatScreen]. Each row shows the latest message in
/// real time.
class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final JobService _jobService = JobService();
  final ChatService _chatService = ChatService();
  Future<List<Issue>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final user = context.read<AuthService>().currentUser;
    if (user == null) {
      _future = Future.value(<Issue>[]);
      return;
    }
    if (user.role == UserRole.worker) {
      // Jobs assigned to this technician are their conversations.
      _future = _jobService.getAssignedJobs(user.uid);
    } else {
      // For a customer: their issues that have an assigned technician.
      _future = _jobService.getCustomerIssues(user.uid).then(
            (list) => list
                .where((i) =>
                    i.assignedWorkerId != null &&
                    i.assignedWorkerId!.isNotEmpty &&
                    i.status != IssueStatus.cancelled)
                .toList(),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().currentUser;
    final isWorker = user?.role == UserRole.worker;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          SfGradientHeader(
            title: tr(context, 'الرسائل'),
            subtitle: tr(context, 'محادثاتك'),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async {
                setState(_load);
                await _future;
              },
              child: FutureBuilder<List<Issue>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 24),
                      children: const [
                        SfSkeletonCard(),
                        SizedBox(height: 10),
                        SfSkeletonCard(),
                        SizedBox(height: 10),
                        SfSkeletonCard(),
                      ],
                    );
                  }
                  final issues = snapshot.data ?? <Issue>[];
                  if (issues.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 90),
                        SfEmptyState(
                          icon: Icons.chat_bubble_outline,
                          title: tr(context, 'لا توجد محادثات بعد'),
                          body: tr(context,
                              'تظهر المحادثات هنا بمجرد تعيين فني لأحد بلاغاتك.'),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsetsDirectional.fromSTEB(14, 16, 14, 24),
                    itemCount: issues.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _ConversationTile(
                      issue: issues[i],
                      isWorker: isWorker,
                      chatService: _chatService,
                      currentUserId: user?.uid ?? '',
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConversationTile extends StatelessWidget {
  final Issue issue;
  final bool isWorker;
  final ChatService chatService;
  final String currentUserId;

  const _ConversationTile({
    required this.issue,
    required this.isWorker,
    required this.chatService,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context) {
    final counterpart = isWorker
        ? (issue.customerName.isNotEmpty
            ? issue.customerName
            : tr(context, 'العميل'))
        : (issue.assignedWorkerName ?? tr(context, 'الفني'));
    final cat = sfCategory(issue.category);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChatScreen(
              issueId: issue.id,
              issueTitle: issue.title,
            ),
          ),
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.all(13),
            child: Row(
              children: [
                // Avatar with a category badge in the bottom-start corner.
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SfAvatar(name: counterpart, size: 48),
                    PositionedDirectional(
                      bottom: -2,
                      start: -2,
                      child: Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: cat.color,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 2),
                        ),
                        child: Icon(cat.icon, size: 11, color: AppColors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: StreamBuilder<List<ChatMessage>>(
                    stream: chatService.getMessages(issue.id),
                    builder: (context, snap) {
                      final msgs = snap.data ?? const <ChatMessage>[];
                      final last = msgs.isNotEmpty ? msgs.last : null;
                      final unread =
                          last != null && last.senderId != currentUserId;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  counterpart,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.charcoal,
                                  ),
                                ),
                              ),
                              if (last != null)
                                Text(
                                  timeago.format(last.timestamp),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.midGrey,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            issue.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.midGrey,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  last != null
                                      ? '${last.senderId == currentUserId ? '${tr(context, 'أنت')}: ' : ''}${last.message}'
                                      : tr(context, 'اضغط لبدء المحادثة'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: unread
                                        ? AppColors.charcoal
                                        : AppColors.midGrey,
                                    fontWeight: unread
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (unread) ...[
                                const SizedBox(width: 6),
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: const BoxDecoration(
                                    color: AppColors.accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
