import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_strings.dart';
import '../../services/auth_service.dart';
import '../../theme/app_colors.dart';
import '../../widgets/smart_button.dart';
import '../auth/login_screen.dart';
import 'worker_home_screen.dart';

/// Gate that only lets ADMIN-APPROVED workers into the worker app.
///
/// A worker whose technician record is still `pending` (or `rejected`) sees a
/// waiting screen instead of the home — so a freshly registered worker cannot
/// accept jobs or do any task until an admin verifies them from the dashboard.
/// Guests (web demo) and verified workers go straight to [WorkerHomeScreen].
class WorkerGate extends StatefulWidget {
  const WorkerGate({super.key});

  @override
  State<WorkerGate> createState() => _WorkerGateState();
}

class _WorkerGateState extends State<WorkerGate> {
  late Future<String> _status;

  @override
  void initState() {
    super.initState();
    _status = context.read<AuthService>().workerVerificationStatus();
  }

  void _retry() {
    setState(() {
      _status = context.read<AuthService>().workerVerificationStatus();
    });
  }

  Future<void> _logout() async {
    await context.read<AuthService>().signOut();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _status,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: AppColors.background,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.navy),
            ),
          );
        }
        final status = snap.data ?? 'unknown';
        if (status == 'verified') return const WorkerHomeScreen();
        return _PendingView(
          status: status,
          onRetry: _retry,
          onLogout: _logout,
        );
      },
    );
  }
}

/// Waiting / rejected / offline screen shown to an unapproved worker.
class _PendingView extends StatelessWidget {
  final String status; // pending | rejected | unknown
  final VoidCallback onRetry;
  final Future<void> Function() onLogout;

  const _PendingView({
    required this.status,
    required this.onRetry,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    final rejected = status == 'rejected';
    final unknown = status == 'unknown';

    final IconData icon = rejected
        ? Icons.cancel_outlined
        : unknown
            ? Icons.wifi_off_rounded
            : Icons.hourglass_top_rounded;
    final Color tone = rejected
        ? AppColors.error
        : unknown
            ? AppColors.midGrey
            : AppColors.goldDeep;
    final String title = rejected
        ? tr(context, 'تم رفض الطلب')
        : unknown
            ? tr(context, 'تعذّر التحقق من الحالة')
            : tr(context, 'حسابك قيد المراجعة');
    final String message = rejected
        ? tr(
            context,
            'للأسف لم تتم الموافقة على حسابك كفنّي. تواصل مع الدعم لمعرفة التفاصيل.',
          )
        : unknown
            ? tr(
                context,
                'تأكّد من اتصالك بالإنترنت ثم اضغط "تحديث الحالة".',
              )
            : tr(
                context,
                'شكرًا لتسجيلك كفنّي. يراجع المشرف بياناتك ووثائقك، وسيُفعَّل حسابك قريبًا. لا يمكنك استلام المهام أو قبول البلاغات قبل الموافقة.',
              );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 46, color: tone),
                ),
                const SizedBox(height: 24),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColors.charcoal,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    height: 1.7,
                    color: AppColors.midGrey,
                  ),
                ),
                const SizedBox(height: 32),
                SmartButton(
                  label: tr(context, 'تحديث الحالة'),
                  icon: Icons.refresh_rounded,
                  width: double.infinity,
                  onPressed: onRetry,
                ),
                const SizedBox(height: 12),
                SmartButton(
                  label: tr(context, 'تسجيل الخروج'),
                  icon: Icons.logout_rounded,
                  isOutlined: true,
                  width: double.infinity,
                  onPressed: () => onLogout(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
