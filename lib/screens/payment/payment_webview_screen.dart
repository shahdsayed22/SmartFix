import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../theme/app_colors.dart';
import '../../l10n/app_strings.dart';

/// Hosts the Paymob hosted-checkout page *inside* the app (instead of kicking
/// the user out to the external browser). When Paymob finishes a transaction it
/// redirects to our server callback (`/api/payments/paymob-callback`, or
/// `/api/payments/callback` in mock mode); we detect that redirect, let it load
/// so the server applies the transaction, then automatically pop back to the
/// checkout screen — which is still polling and will show the final status.
///
/// Pops with `true` once the callback redirect is reached, or `null` if the
/// user backs out manually (the checkout screen keeps polling either way).
class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;

  const PaymentWebViewScreen({super.key, required this.paymentUrl});

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  // Substrings that mark Paymob's return-to-us redirect. Once any of these
  // appears in the navigated URL, the payment leg is over and we head back.
  static const List<String> _returnMarkers = [
    '/api/payments/paymob-callback',
    '/api/payments/callback',
  ];

  late final WebViewController _controller;
  int _progress = 0;
  bool _finished = false; // guards against popping twice

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onUrlChange: (change) => _maybeFinish(change.url),
          onPageStarted: _maybeFinish,
          onPageFinished: _maybeFinish,
          onNavigationRequest: (req) {
            // Allow the redirect to load (so the GET callback applies the
            // transaction on our server), but flag that we should head back.
            _maybeFinish(req.url);
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _maybeFinish(String? url) {
    if (_finished || url == null) return;
    final u = url.toLowerCase();
    if (_returnMarkers.any(u.contains)) {
      _finished = true;
      if (mounted) Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(tr(context, 'إتمام الدفع')),
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: tr(context, 'إلغاء'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress / 100,
                  minHeight: 3,
                  backgroundColor: Colors.white24,
                ),
              )
            : null,
      ),
      body: SafeArea(child: WebViewWidget(controller: _controller)),
    );
  }
}
