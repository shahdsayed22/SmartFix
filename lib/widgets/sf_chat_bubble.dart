import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_colors.dart';

/// A single chat message bubble. [mine] right-aligns the bubble in navy
/// with white text; otherwise it is a left-aligned white bubble with a
/// sender avatar. When [showName] is true (other party, first in a run)
/// the [senderName] is shown above the bubble and as the avatar initial.
class SfChatBubble extends StatelessWidget {
  final String text;

  /// Pre-formatted clock time (e.g. "4:20 PM").
  final String time;
  final bool mine;
  final String senderName;
  final bool showName;

  const SfChatBubble({
    super.key,
    required this.text,
    required this.time,
    this.mine = false,
    this.senderName = '',
    this.showName = false,
  });

  @override
  Widget build(BuildContext context) {
    final initial =
        senderName.trim().isNotEmpty ? senderName.trim()[0].toUpperCase() : '?';

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? AppColors.navy : AppColors.surface,
        border: mine ? null : Border.all(color: AppColors.lineSoft),
        borderRadius: BorderRadiusDirectional.only(
          topStart: const Radius.circular(18),
          topEnd: const Radius.circular(18),
          bottomStart: Radius.circular(mine ? 18 : 5),
          bottomEnd: Radius.circular(mine ? 5 : 18),
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.navyShadow,
            blurRadius: 8,
            spreadRadius: -4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 14,
              height: 1.4,
              color: mine ? AppColors.white : AppColors.charcoal,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time,
            style: GoogleFonts.ibmPlexSansArabic(
              fontSize: 10,
              color:
                  mine
                      ? AppColors.white.withValues(alpha: 0.65)
                      : AppColors.midGrey,
            ),
          ),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!mine)
            showName
                ? Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.navy,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    initial,
                    style: GoogleFonts.ibmPlexSansArabic(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.gold,
                    ),
                  ),
                )
                : const SizedBox(width: 28),
          if (!mine) const SizedBox(width: 8),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.74,
              ),
              child: Column(
                crossAxisAlignment:
                    mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!mine && showName)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: 4,
                        bottom: 3,
                      ),
                      child: Text(
                        senderName,
                        style: GoogleFonts.ibmPlexSansArabic(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.navy,
                        ),
                      ),
                    ),
                  bubble,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
