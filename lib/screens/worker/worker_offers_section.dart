import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';
import '../../services/api_service.dart';
import '../../widgets/smart_button.dart';
import '../../widgets/sf_icons.dart';
import '../../widgets/sf_feedback.dart';

/// Uber-style "عروض جديدة" section on the worker home: jobs the dispatch
/// workflow has OFFERED to this technician (status == 'offered', offeredTo ==
/// my uid). Each offer shows the distance + upfront fare with Accept / Decline.
/// Accept locks the job; Decline cascades the offer to the next candidate.
///
/// Renders nothing when there are no live offers, so it stays out of the way.
class WorkerOffersSection extends StatefulWidget {
  final ApiService api;

  /// The technician's Firebase uid (matches Issue.offeredTo).
  final String uid;

  /// Called after an accept/decline so the parent can refresh its job lists.
  final VoidCallback? onChanged;

  const WorkerOffersSection({
    super.key,
    required this.api,
    required this.uid,
    this.onChanged,
  });

  @override
  State<WorkerOffersSection> createState() => _WorkerOffersSectionState();
}

class _WorkerOffersSectionState extends State<WorkerOffersSection> {
  late Future<List<Map<String, dynamic>>> _future;
  String? _busyId; // id of the offer currently being accepted/declined

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Map<String, dynamic>>> _load() {
    return widget.api.getIssues(offeredTo: widget.uid, status: 'offered');
  }

  void _refresh() {
    setState(() => _future = _load());
    widget.onChanged?.call();
  }

  String _idOf(Map<String, dynamic> m) =>
      (m['id'] ?? m['_id'])?.toString() ?? '';

  /// Current offer's distance (km) from the queue at offerIndex, if present.
  double? _kmOf(Map<String, dynamic> m) {
    final queue = m['offerQueue'];
    final idx = (m['offerIndex'] as num?)?.toInt() ?? 0;
    if (queue is List && idx >= 0 && idx < queue.length) {
      final km = (queue[idx] as Map?)?['km'];
      if (km is num) return km.toDouble();
    }
    return null;
  }

  num? _fareOf(Map<String, dynamic> m) {
    final queue = m['offerQueue'];
    final idx = (m['offerIndex'] as num?)?.toInt() ?? 0;
    if (queue is List && idx >= 0 && idx < queue.length) {
      final fare = (queue[idx] as Map?)?['fare'];
      if (fare is num) return fare;
    }
    final price = m['price'];
    return price is num ? price : null;
  }

  Future<void> _accept(Map<String, dynamic> m) async {
    final id = _idOf(m);
    if (id.isEmpty) return;
    setState(() => _busyId = id);
    try {
      await widget.api.acceptOffer(id, technicianId: widget.uid, by: 'worker');
      if (!mounted) return;
      SfToast.show(context, tr(context, 'تم قبول المهمة — في طريقك إلى العميل'),
          tone: SfTone.success);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      SfToast.show(context, '${tr(context, 'خطأ')}: $e', tone: SfTone.error);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _decline(Map<String, dynamic> m) async {
    final id = _idOf(m);
    if (id.isEmpty) return;
    setState(() => _busyId = id);
    try {
      await widget.api.declineOffer(id, technicianId: widget.uid, by: 'worker');
      if (!mounted) return;
      SfToast.show(context, tr(context, 'تم رفض العرض'), tone: SfTone.info);
      _refresh();
    } catch (e) {
      if (!mounted) return;
      SfToast.show(context, '${tr(context, 'خطأ')}: $e', tone: SfTone.error);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        final offers = snapshot.data ?? const [];
        if (offers.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(18, 0, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.bolt, size: 18, color: AppColors.gold),
                  const SizedBox(width: 7),
                  Text(
                    tr(context, 'عروض جديدة'),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.charcoal,
                        ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${offers.length}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.gold,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (int i = 0; i < offers.length; i++)
                Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 12),
                  child: _OfferCard(
                    offer: offers[i],
                    cat: sfCategory((offers[i]['category'] ?? 'plumbing').toString()),
                    km: _kmOf(offers[i]),
                    fare: _fareOf(offers[i]),
                    busy: _busyId == _idOf(offers[i]),
                    onAccept: () => _accept(offers[i]),
                    onDecline: () => _decline(offers[i]),
                  ).animate().fadeIn(
                        delay: Duration(milliseconds: i * 70),
                        duration: 350.ms,
                      ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _OfferCard extends StatelessWidget {
  final Map<String, dynamic> offer;
  final SfCategory cat;
  final double? km;
  final num? fare;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const _OfferCard({
    required this.offer,
    required this.cat,
    required this.km,
    required this.fare,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = (offer['title'] ?? '').toString();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cat.color.withValues(alpha: 0.30)),
        boxShadow: [
          BoxShadow(
            color: cat.color.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: cat.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(cat.icon, size: 20, color: cat.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isNotEmpty ? title : cat.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.charcoal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cat.label,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.midGrey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── distance + fare chips ──
          Row(
            children: [
              if (km != null)
                _MetricChip(
                  icon: Icons.near_me,
                  label: '${km!.toStringAsFixed(1)} ${tr(context, 'كم')}',
                  color: AppColors.teal,
                ),
              if (km != null && fare != null) const SizedBox(width: 8),
              if (fare != null)
                _MetricChip(
                  icon: Icons.payments_outlined,
                  label: '${fare!.round()} ${tr(context, 'ج.م')}',
                  color: AppColors.success,
                ),
            ],
          ),
          const SizedBox(height: 14),
          // ── accept / decline ──
          Row(
            children: [
              Expanded(
                child: SmartButton(
                  label: tr(context, 'قبول'),
                  icon: Icons.check_rounded,
                  isLoading: busy,
                  onPressed: busy ? null : onAccept,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SmartButton(
                  label: tr(context, 'رفض'),
                  icon: Icons.close_rounded,
                  isOutlined: true,
                  onPressed: busy ? null : onDecline,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetricChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}
