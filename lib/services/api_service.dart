import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

/// HTTP client for communicating with the Next.js dashboard API.
/// This bridges the Flutter app with the MongoDB-backed dashboard,
/// making both systems share a single source of truth.
class ApiService {
  /// Base URL for the Next.js dashboard API.
  ///
  /// Published native apps (Android / iOS / desktop) talk to the DEPLOYED
  /// Vercel API by default, so a physical phone works out of the box without a
  /// laptop on the same Wi-Fi. For local development against `npm run dev`,
  /// override the host at build/run time, e.g.:
  ///   flutter run --dart-define=API_BASE=http://192.168.1.35:3000/api
  ///   (Android emulator → 10.0.2.2:3000/api · USB → adb reverse + 127.0.0.1)
  static const String _prodApiBase = 'https://smartfix-six.vercel.app/api';

  static String get _baseUrl {
    // A compile-time override wins everywhere (local dev / LAN demo).
    const override = String.fromEnvironment('API_BASE');
    if (override.isNotEmpty) return override;
    if (kIsWeb) return _webBaseUrl;
    // Native platforms → the deployed Vercel API.
    return _prodApiBase;
  }

  /// On web (PWA) the page is served from the laptop over the LAN, so the API
  /// lives on the SAME host at port 3000 — NOT the device's own `localhost`
  /// (which on a phone would point back at the phone). Build-time override:
  /// `flutter build web --dart-define=API_BASE=http://192.168.1.35:3000/api`.
  static String get _webBaseUrl {
    const override = String.fromEnvironment('API_BASE');
    if (override.isNotEmpty) return override;
    final host = Uri.base.host;
    final isLocal = host == 'localhost' ||
        host == '127.0.0.1' ||
        RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host);
    // Local dev: the dashboard/API runs on :3000 (PWA is served on :8090).
    // Deployed (e.g. Vercel): the API is same-origin under /api over HTTPS.
    return isLocal ? 'http://$host:3000/api' : '${Uri.base.origin}/api';
  }

  final http.Client _client = http.Client();
  // Generous timeout: the dev dashboard cold-compiles routes on first hit and
  // mobile-over-Wi-Fi can spike, so 10s was too tight (caused "TimeoutException
  // after 0:00:10" on actions like accept-job). 30s gives ample headroom.
  static const Duration _timeout = Duration(seconds: 30);

  // ─── Issues ──────────────────────────────────────────────────────

  /// Fetch all issues, optionally filtered by category, status, or customerId
  Future<List<Map<String, dynamic>>> getIssues({
    String? category,
    String? status,
    String? customerId,
    String? offeredTo,
    int limit = 500,
  }) async {
    final queryParams = <String, String>{'limit': limit.toString()};
    if (category != null) queryParams['category'] = category;
    if (status != null) queryParams['status'] = status;
    if (customerId != null) queryParams['customerId'] = customerId;
    if (offeredTo != null) queryParams['offeredTo'] = offeredTo;

    final uri = Uri.parse(
      '$_baseUrl/issues',
    ).replace(queryParameters: queryParams);
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['issues'] ?? []);
    }
    throw Exception('Failed to fetch issues: ${response.statusCode}');
  }

  /// Create a new issue
  Future<Map<String, dynamic>> createIssue(
    Map<String, dynamic> issueData,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/issues'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(issueData),
        )
        .timeout(_timeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to create issue: ${response.statusCode}');
  }

  /// Update an issue (status, assignment, etc.)
  Future<Map<String, dynamic>> updateIssue(
    String issueId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _client
        .put(
          Uri.parse('$_baseUrl/issues/$issueId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(updates),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to update issue: ${response.statusCode}');
  }

  // ─── Technicians ────────────────────────────────────────────────

  /// Fetch technicians, optionally filtered by category
  Future<List<Map<String, dynamic>>> getTechnicians({String? category}) async {
    final queryParams = <String, String>{};
    if (category != null) queryParams['category'] = category;

    final uri = Uri.parse(
      '$_baseUrl/technicians',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['technicians'] ?? []);
    }
    throw Exception('Failed to fetch technicians: ${response.statusCode}');
  }

  /// Fetch a single technician by its Firebase [uid], or null if none exists
  /// yet. Used by the app to read its own admin-verification status.
  Future<Map<String, dynamic>?> getTechnicianByUid(String uid) async {
    final uri = Uri.parse('$_baseUrl/technicians')
        .replace(queryParameters: {'uid': uid, 'limit': '1'});
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final list = List<Map<String, dynamic>>.from(data['technicians'] ?? []);
      return list.isEmpty ? null : list.first;
    }
    throw Exception('Failed to fetch technician: ${response.statusCode}');
  }

  /// Create or update a technician record (upserts by uid server-side) so a
  /// registered worker shows up in the dashboard's Technicians management.
  Future<Map<String, dynamic>> syncTechnician(
    Map<String, dynamic> technicianData,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/technicians'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(technicianData),
        )
        .timeout(_timeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to sync technician: ${response.statusCode}');
  }

  // ─── Users ──────────────────────────────────────────────────────

  /// Fetch users from the dashboard
  Future<List<Map<String, dynamic>>> getUsers() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/users'))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['users'] ?? []);
    }
    throw Exception('Failed to fetch users: ${response.statusCode}');
  }

  /// Create or update a user in MongoDB
  Future<Map<String, dynamic>> syncUser(Map<String, dynamic> userData) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/users'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(userData),
        )
        .timeout(_timeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to sync user: ${response.statusCode}');
  }

  // ─── Analytics ──────────────────────────────────────────────────

  /// Fetch dashboard analytics
  Future<Map<String, dynamic>> getAnalytics() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/analytics'))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to fetch analytics: ${response.statusCode}');
  }

  // ─── Tickets ────────────────────────────────────────────────────

  /// Fetch support tickets, optionally filtered.
  Future<List<Map<String, dynamic>>> getTickets({
    String? customerId,
    String? status,
    String? priority,
    String? search,
    int limit = 200,
  }) async {
    final queryParams = <String, String>{'limit': limit.toString()};
    if (customerId != null) queryParams['customerId'] = customerId;
    if (status != null) queryParams['status'] = status;
    if (priority != null) queryParams['priority'] = priority;
    if (search != null) queryParams['search'] = search;

    final uri = Uri.parse(
      '$_baseUrl/tickets',
    ).replace(queryParameters: queryParams);
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['tickets'] ?? []);
    }
    throw Exception('Failed to fetch tickets: ${response.statusCode}');
  }

  /// Create a support ticket. May include a seed `messages` list (chatbot).
  Future<Map<String, dynamic>> createTicket(
    Map<String, dynamic> ticketData,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/tickets'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(ticketData),
        )
        .timeout(_timeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to create ticket: ${response.statusCode}');
  }

  /// Fetch a single ticket by id.
  Future<Map<String, dynamic>> getTicket(String ticketId) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/tickets/$ticketId'))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to fetch ticket: ${response.statusCode}');
  }

  /// Append a message to a ticket thread.
  Future<Map<String, dynamic>> replyTicket(
    String ticketId,
    Map<String, dynamic> message,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/tickets/$ticketId/messages'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(message),
        )
        .timeout(_timeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to reply to ticket: ${response.statusCode}');
  }

  /// Update a ticket (status, priority, ...).
  Future<Map<String, dynamic>> updateTicket(
    String ticketId,
    Map<String, dynamic> updates,
  ) async {
    final response = await _client
        .patch(
          Uri.parse('$_baseUrl/tickets/$ticketId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(updates),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to update ticket: ${response.statusCode}');
  }

  // ─── Reviews ────────────────────────────────────────────────────

  /// Fetch reviews by technicianId or customerId.
  Future<List<Map<String, dynamic>>> getReviews({
    String? technicianId,
    String? customerId,
  }) async {
    final queryParams = <String, String>{};
    if (technicianId != null) queryParams['technicianId'] = technicianId;
    if (customerId != null) queryParams['customerId'] = customerId;

    final uri = Uri.parse(
      '$_baseUrl/reviews',
    ).replace(queryParameters: queryParams.isNotEmpty ? queryParams : null);
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['reviews'] ?? []);
    }
    throw Exception('Failed to fetch reviews: ${response.statusCode}');
  }

  /// Create a review for a completed job.
  /// Throws on 409 (a review for that issueId already exists).
  Future<Map<String, dynamic>> createReview(
    Map<String, dynamic> reviewData,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/reviews'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(reviewData),
        )
        .timeout(_timeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    }
    if (response.statusCode == 409) {
      throw Exception('Review already exists for this issue');
    }
    throw Exception('Failed to create review: ${response.statusCode}');
  }

  // ─── Notifications ──────────────────────────────────────────────

  /// Fetch notifications for a user, optionally only unread ones.
  Future<List<Map<String, dynamic>>> getNotifications(
    String userId, {
    bool unreadOnly = false,
  }) async {
    final queryParams = <String, String>{'userId': userId};
    if (unreadOnly) queryParams['unreadOnly'] = 'true';

    final uri = Uri.parse(
      '$_baseUrl/notifications',
    ).replace(queryParameters: queryParams);
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['notifications'] ?? []);
    }
    throw Exception('Failed to fetch notifications: ${response.statusCode}');
  }

  /// Mark a single notification as read, or all of a user's notifications
  /// when [id] is null and [userId] is provided.
  Future<Map<String, dynamic>> markNotificationRead({
    String? id,
    String? userId,
  }) async {
    final body = <String, dynamic>{};
    if (id != null) body['id'] = id;
    if (userId != null) body['userId'] = userId;

    final response = await _client
        .patch(
          Uri.parse('$_baseUrl/notifications'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to mark notification read: ${response.statusCode}');
  }

  // ─── Payments ───────────────────────────────────────────────────

  /// Create a payment invoice (server computes figures + provider invoice).
  Future<Map<String, dynamic>> createPayment(
    Map<String, dynamic> paymentData,
  ) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/payments'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(paymentData),
        )
        .timeout(_timeout);

    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to create payment: ${response.statusCode}');
  }

  /// Fetch payments (invoices), optionally filtered by customer / technician /
  /// issue / status. Used by the wallet + earnings screens for real history.
  Future<List<Map<String, dynamic>>> getPayments({
    String? customerId,
    String? technicianId,
    String? issueId,
    String? status,
    int limit = 100,
  }) async {
    final queryParams = <String, String>{'limit': limit.toString()};
    if (customerId != null) queryParams['customerId'] = customerId;
    if (technicianId != null) queryParams['technicianId'] = technicianId;
    if (issueId != null) queryParams['issueId'] = issueId;
    if (status != null) queryParams['status'] = status;

    final uri = Uri.parse(
      '$_baseUrl/payments',
    ).replace(queryParameters: queryParams);
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['payments'] ?? []);
    }
    throw Exception('Failed to fetch payments: ${response.statusCode}');
  }

  /// Fetch a payment by id.
  Future<Map<String, dynamic>> getPayment(String paymentId) async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/payments/$paymentId'))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to fetch payment: ${response.statusCode}');
  }

  // ─── Wallet (Stage 5 ledger) ────────────────────────────────────

  /// A worker's in-app wallet: { balance, totalEarned, currency, transactions }.
  Future<Map<String, dynamic>> getWallet(String technicianId) async {
    final uri = Uri.parse('$_baseUrl/wallet')
        .replace(queryParameters: {'technicianId': technicianId});
    final response = await _client.get(uri).timeout(_timeout);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to fetch wallet: ${response.statusCode}');
  }

  /// Withdraw (simulated cash-out) from a worker's wallet. Omit [amount] to
  /// withdraw the full balance. Returns { ok, withdrawn, balance, transaction }.
  Future<Map<String, dynamic>> withdrawWallet(
    String technicianId, {
    double? amount,
  }) async {
    final body = <String, dynamic>{'technicianId': technicianId};
    if (amount != null) body['amount'] = amount;
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/wallet/withdraw'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(_timeout);
    if (response.statusCode == 201 || response.statusCode == 200) {
      return json.decode(response.body);
    }
    String msg = 'Withdrawal failed (${response.statusCode})';
    try {
      final body = json.decode(response.body);
      if (body is Map && body['error'] != null) msg = body['error'].toString();
    } catch (_) {/* keep default */}
    throw Exception(msg);
  }

  /// Update a payment's status (e.g. to 'paid').
  Future<Map<String, dynamic>> updatePaymentStatus(
    String paymentId,
    String status,
  ) async {
    final response = await _client
        .patch(
          Uri.parse('$_baseUrl/payments/$paymentId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'status': status}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to update payment: ${response.statusCode}');
  }

  // ─── Settings ───────────────────────────────────────────────────

  /// Fetch the commission/pricing settings singleton.
  Future<Map<String, dynamic>> getCommissionSettings() async {
    final response = await _client
        .get(Uri.parse('$_baseUrl/settings/commission'))
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception(
      'Failed to fetch commission settings: ${response.statusCode}',
    );
  }

  // ─── NLP ────────────────────────────────────────────────────────

  /// Log a reported issue's text + final category/urgency as a labelled
  /// training sample (learning hook). Fire-and-forget — builds a corpus to
  /// retrain the Arabic classifier on later. Silently no-ops on short text.
  Future<void> logTrainingSample({
    required String text,
    required String category,
    required String urgency,
    String aiSuggestedCategory = '',
    String aiMethod = '',
    bool corrected = false,
  }) async {
    if (text.trim().length < 3) return;
    await _client
        .post(
          Uri.parse('$_baseUrl/nlp/samples'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'text': text.trim(),
            'category': category,
            'urgency': urgency,
            'aiSuggestedCategory': aiSuggestedCategory,
            'aiMethod': aiMethod,
            'corrected': corrected,
            'source': 'report',
          }),
        )
        .timeout(_timeout);
  }

  /// Classify free text into a service category (server-side detectCategory).
  /// Returns `{ category, confidence, scores, matched }`.
  Future<Map<String, dynamic>> classifyText(String text) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/nlp/classify'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'text': text}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to classify text: ${response.statusCode}');
  }

  /// Send a turn to the bilingual support assistant. [messages] is the running
  /// session transcript (`[{role:'user'|'assistant', text}]`); the server grounds
  /// answers in the user's live data and may escalate to a support ticket.
  /// Returns `{ reply, intent, data?, suggestions[], escalation?, method }`.
  Future<Map<String, dynamic>> supportChat({
    required List<Map<String, String>> messages,
    required String lang,
    required String role,
    required String userId,
    String userName = '',
    String? issueId,
    String? paymentId,
  }) async {
    final response = await _client
        .post(
          Uri.parse('$_baseUrl/support-chat'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'messages': messages,
            'lang': lang,
            'role': role,
            'userId': userId,
            'userName': userName,
            'context': {
              if (issueId != null) 'issueId': issueId,
              if (paymentId != null) 'paymentId': paymentId,
            },
          }),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('support-chat failed: ${response.statusCode}');
  }

  // ─── Uber-style offer/accept dispatch (issues/[id] PATCH) ───────

  /// Worker → accept a job offered to them: status becomes assigned.
  Future<Map<String, dynamic>> acceptOffer(
    String issueId, {
    required String technicianId,
    String? by,
  }) async {
    return _patchIssueAction(issueId, {
      'action': 'accept-offer',
      'technicianId': technicianId,
      if (by != null) 'by': by,
    });
  }

  /// Worker → decline an offer: it cascades to the next candidate (or the
  /// issue returns to pending if the queue is exhausted).
  Future<Map<String, dynamic>> declineOffer(
    String issueId, {
    required String technicianId,
    String? by,
  }) async {
    return _patchIssueAction(issueId, {
      'action': 'decline-offer',
      'technicianId': technicianId,
      if (by != null) 'by': by,
    });
  }

  // ─── Completion lifecycle (issues/[id] PATCH with action) ───────

  /// Worker → request completion: status becomes awaitingApproval.
  Future<Map<String, dynamic>> requestCompletion(
    String issueId, {
    String summary = '',
    List<String> photos = const [],
    String? by,
  }) async {
    return _patchIssueAction(issueId, {
      'action': 'request-completion',
      'completionSummary': summary,
      'completionPhotos': photos,
      if (by != null) 'by': by,
    });
  }

  /// Customer → approve completion: status becomes awaitingPayment.
  Future<Map<String, dynamic>> approveCompletion(
    String issueId, {
    String? by,
  }) async {
    return _patchIssueAction(issueId, {
      'action': 'approve-completion',
      if (by != null) 'by': by,
    });
  }

  /// Customer → reject completion: status returns to inProgress (or disputed).
  Future<Map<String, dynamic>> rejectCompletion(
    String issueId, {
    required String rejectionReason,
    String? by,
  }) async {
    return _patchIssueAction(issueId, {
      'action': 'reject-completion',
      'rejectionReason': rejectionReason,
      if (by != null) 'by': by,
    });
  }

  Future<Map<String, dynamic>> _patchIssueAction(
    String issueId,
    Map<String, dynamic> body,
  ) async {
    final response = await _client
        .patch(
          Uri.parse('$_baseUrl/issues/$issueId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception(
      'Failed to ${body['action']} on issue: ${response.statusCode}',
    );
  }

  // ─── Worker gating ──────────────────────────────────────────────

  /// Fetch pending, unassigned jobs whose category is in the worker's skills.
  Future<List<Map<String, dynamic>>> getAvailableJobsForWorker(
    List<String> skills, {
    int limit = 500,
  }) async {
    final queryParams = <String, String>{'limit': limit.toString()};
    if (skills.isNotEmpty) {
      queryParams['availableForCategories'] = skills.join(',');
    }

    final uri = Uri.parse(
      '$_baseUrl/issues',
    ).replace(queryParameters: queryParams);
    final response = await _client.get(uri).timeout(_timeout);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return List<Map<String, dynamic>>.from(data['issues'] ?? []);
    }
    throw Exception('Failed to fetch available jobs: ${response.statusCode}');
  }

  // ─── Technician verification / categories ───────────────────────

  /// Verify or reject a technician (sets verificationStatus + isVerified).
  Future<Map<String, dynamic>> verifyTechnician(
    String technicianId, {
    bool verified = true,
  }) async {
    final response = await _client
        .patch(
          Uri.parse('$_baseUrl/technicians/$technicianId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'action': verified ? 'verify' : 'reject'}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception('Failed to verify technician: ${response.statusCode}');
  }

  /// Assign the multi-skill category list for a technician.
  Future<Map<String, dynamic>> setTechnicianCategories(
    String technicianId,
    List<String> categories,
  ) async {
    final response = await _client
        .patch(
          Uri.parse('$_baseUrl/technicians/$technicianId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'categories': categories}),
        )
        .timeout(_timeout);

    if (response.statusCode == 200) {
      return json.decode(response.body);
    }
    throw Exception(
      'Failed to set technician categories: ${response.statusCode}',
    );
  }

  void dispose() {
    _client.close();
  }
}
