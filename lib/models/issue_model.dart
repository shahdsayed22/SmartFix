import 'package:cloud_firestore/cloud_firestore.dart';

enum IssueCategory {
  plumbing,
  electrical,
  carpentry,
  painting,
  hvac,
  cleaning,
  applianceRepair,
  welding,
  tiling,
}

enum IssueUrgency { low, medium, high, emergency }

enum IssueStatus {
  pending,
  offered,
  assigned,
  inProgress,
  // Worker reported the work done; waiting for the customer to confirm.
  awaitingApproval,
  // Customer approved; waiting for payment to settle.
  awaitingPayment,
  completed,
  cancelled,
}

class Issue {
  final String id;
  final String customerId;
  final String customerName;
  final String title;
  final String description;
  final IssueCategory category;
  final IssueUrgency urgency;
  final List<String> photoUrls;
  final double latitude;
  final double longitude;
  final String address;
  final IssueStatus status;
  final String? assignedWorkerId;
  final String? assignedWorkerName;
  // Locked upfront fare for the job (server `Issue.price`, set on offer accept).
  // 0 when not yet priced. The payment screen bills this, not a category default.
  final double price;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── AI triage fields (populated server-side by the issue-triage workflow) ──
  // These describe the heuristic/anomaly BASELINE that classified the issue —
  // not the trained-ensemble research metrics (those live on the dashboard's
  // AI Insights page). Null until the workflow has processed the issue.
  /// Urgency score in [0,1] from the triage workflow.
  final double? aiUrgencyScore;

  /// Anomaly score in [0,1] from the triage workflow.
  final double? aiAnomalyScore;

  /// Category key the AI suggested (snake_case), e.g. 'plumbing'.
  final String? aiSuggestedCategory;

  /// Classifier method id, e.g. 'heuristic' or a trained-model id.
  final String? aiMethod;

  /// Classifier confidence in [0,1].
  final double? aiConfidence;

  /// Keywords the classifier matched (for explainability).
  final List<String> aiMatched;

  Issue({
    required this.id,
    required this.customerId,
    this.customerName = '',
    required this.title,
    required this.description,
    required this.category,
    this.urgency = IssueUrgency.medium,
    this.photoUrls = const [],
    required this.latitude,
    required this.longitude,
    this.address = '',
    this.status = IssueStatus.pending,
    this.assignedWorkerId,
    this.assignedWorkerName,
    this.price = 0,
    this.aiUrgencyScore,
    this.aiAnomalyScore,
    this.aiSuggestedCategory,
    this.aiMethod,
    this.aiConfidence,
    this.aiMatched = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  /// True when the triage workflow has produced any AI signal for this issue.
  bool get hasAiTriage =>
      aiUrgencyScore != null ||
      aiAnomalyScore != null ||
      (aiSuggestedCategory != null && aiSuggestedCategory!.isNotEmpty);

  /// Convert camelCase enum to snake_case for MongoDB
  static String _categoryToApi(IssueCategory cat) {
    switch (cat) {
      case IssueCategory.applianceRepair:
        return 'appliance_repair';
      default:
        return cat.name;
    }
  }

  /// Parse snake_case category from MongoDB to Dart enum
  static IssueCategory _categoryFromApi(String? value) {
    if (value == null) return IssueCategory.plumbing;
    // Handle snake_case from MongoDB
    if (value == 'appliance_repair') return IssueCategory.applianceRepair;
    return IssueCategory.values.firstWhere(
      (c) => c.name == value,
      orElse: () => IssueCategory.plumbing,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'customerName': customerName,
      'title': title,
      'description': description,
      'category': _categoryToApi(category),
      'urgency': urgency.name,
      'photoUrls': photoUrls,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'status': status.name,
      'assignedWorkerId': assignedWorkerId,
      'assignedWorkerName': assignedWorkerName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  /// Convert to a JSON-safe map for the REST API (no Firestore types).
  /// Accepts optional customer contact info to enrich the issue data.
  Map<String, dynamic> toApiMap({
    String? customerEmail,
    String? customerPhone,
  }) {
    return {
      'customerId': customerId,
      'customerName': customerName,
      'customerEmail': customerEmail ?? '',
      'customerPhone': customerPhone ?? '',
      'title': title,
      'description': description,
      'category': _categoryToApi(category),
      'urgency': urgency.name,
      'photoUrls': photoUrls,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
      'status': status.name,
      'assignedTechnicianId': assignedWorkerId,
      'assignedTechnicianName': assignedWorkerName,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory Issue.fromMap(Map<String, dynamic> map) {
    return Issue(
      id: map['id'] ?? '',
      customerId: map['customerId'] ?? '',
      customerName: map['customerName'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      category: _categoryFromApi(map['category'] as String?),
      urgency: IssueUrgency.values.firstWhere(
        (u) => u.name == map['urgency'],
        orElse: () => IssueUrgency.medium,
      ),
      photoUrls: List<String>.from(map['photoUrls'] ?? []),
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      address: map['address'] ?? '',
      status: IssueStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => IssueStatus.pending,
      ),
      assignedWorkerId: map['assignedTechnicianId'] ?? map['assignedWorkerId'],
      assignedWorkerName:
          map['assignedTechnicianName'] ?? map['assignedWorkerName'],
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      aiUrgencyScore: (map['aiUrgencyScore'] as num?)?.toDouble(),
      aiAnomalyScore: (map['aiAnomalyScore'] as num?)?.toDouble(),
      aiSuggestedCategory: (map['aiSuggestedCategory'] as String?)?.isNotEmpty == true
          ? map['aiSuggestedCategory'] as String
          : null,
      aiMethod: _aiClassificationString(map['aiClassification'], 'method'),
      aiConfidence: _aiClassificationDouble(map['aiClassification'], 'confidence'),
      aiMatched: _aiClassificationList(map['aiClassification'], 'matched'),
      createdAt: _parseDate(map['createdAt']),
      updatedAt: _parseDate(map['updatedAt']),
    );
  }

  // ── helpers to read fields out of the backend's `aiClassification` object ──
  static String? _aiClassificationString(dynamic c, String key) {
    if (c is Map && c[key] is String && (c[key] as String).isNotEmpty) {
      return c[key] as String;
    }
    return null;
  }

  static double? _aiClassificationDouble(dynamic c, String key) {
    if (c is Map && c[key] is num) return (c[key] as num).toDouble();
    return null;
  }

  static List<String> _aiClassificationList(dynamic c, String key) {
    if (c is Map && c[key] is List) {
      return (c[key] as List).map((e) => e.toString()).toList();
    }
    return const [];
  }

  /// Parse dates from multiple formats: Firestore Timestamp, DateTime, ISO string
  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }

  Issue copyWith({
    IssueStatus? status,
    String? assignedWorkerId,
    String? assignedWorkerName,
  }) {
    return Issue(
      id: id,
      customerId: customerId,
      customerName: customerName,
      title: title,
      description: description,
      category: category,
      urgency: urgency,
      photoUrls: photoUrls,
      latitude: latitude,
      longitude: longitude,
      address: address,
      status: status ?? this.status,
      assignedWorkerId: assignedWorkerId ?? this.assignedWorkerId,
      assignedWorkerName: assignedWorkerName ?? this.assignedWorkerName,
      price: price,
      aiUrgencyScore: aiUrgencyScore,
      aiAnomalyScore: aiAnomalyScore,
      aiSuggestedCategory: aiSuggestedCategory,
      aiMethod: aiMethod,
      aiConfidence: aiConfidence,
      aiMatched: aiMatched,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  String get categoryLabel {
    switch (category) {
      case IssueCategory.plumbing:
        return 'Plumbing';
      case IssueCategory.electrical:
        return 'Electrical';
      case IssueCategory.carpentry:
        return 'Carpentry';
      case IssueCategory.painting:
        return 'Painting';
      case IssueCategory.hvac:
        return 'HVAC';
      case IssueCategory.cleaning:
        return 'Cleaning';
      case IssueCategory.applianceRepair:
        return 'Appliance Repair';
      case IssueCategory.welding:
        return 'Welding';
      case IssueCategory.tiling:
        return 'Tiling';
    }
  }

  String get statusLabel {
    switch (status) {
      case IssueStatus.pending:
        return 'Pending';
      case IssueStatus.offered:
        return 'Offered';
      case IssueStatus.assigned:
        return 'Assigned';
      case IssueStatus.inProgress:
        return 'In Progress';
      case IssueStatus.awaitingApproval:
        return 'Awaiting Customer Approval';
      case IssueStatus.awaitingPayment:
        return 'Awaiting Payment';
      case IssueStatus.completed:
        return 'Completed';
      case IssueStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get urgencyLabel {
    switch (urgency) {
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
}
