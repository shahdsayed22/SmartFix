// Support ticket model (admin ↔ client) — mirrors Mongo `Ticket` schema (§4).
// Pure JSON model backed by the Next.js / MongoDB REST API (no Firestore types).

/// One message inside a [Ticket] (the embedded `messages` subdoc / §4
/// `ticket_messages`). `senderRole` ∈ { customer, admin, bot }.
class TicketMessage {
  final String senderId;
  final String senderRole; // 'customer' | 'admin' | 'bot'
  final String senderName;
  final String text;
  final List<String> attachments;
  final DateTime at;

  TicketMessage({
    this.senderId = '',
    this.senderRole = 'customer',
    this.senderName = '',
    this.text = '',
    this.attachments = const [],
    DateTime? at,
  }) : at = at ?? DateTime.now();

  factory TicketMessage.fromJson(Map<String, dynamic> json) {
    return TicketMessage(
      senderId: json['senderId'] ?? '',
      senderRole: json['senderRole'] ?? 'customer',
      senderName: json['senderName'] ?? '',
      text: json['text'] ?? '',
      attachments: List<String>.from(json['attachments'] ?? const []),
      at: _parseDate(json['at']),
    );
  }

  Map<String, dynamic> toJson() => {
        'senderId': senderId,
        'senderRole': senderRole,
        'senderName': senderName,
        'text': text,
        'attachments': attachments,
        'at': at.toIso8601String(),
      };
}

/// A support ticket. `category` ∈ {general, payment, service_quality,
/// technician, account, complaint, other}; `status` ∈ {open, pending,
/// resolved, closed}; `priority` ∈ {low, medium, high}; `source` ∈
/// {manual, chatbot}.
class Ticket {
  final String id; // Mongo _id (if present)
  final String ticketId; // human-readable e.g. TKT-1A2B3C
  final String customerId;
  final String customerName;
  final String subject;
  final String category;
  final String status;
  final String priority;
  final String relatedIssueId;
  final String source;
  final List<TicketMessage> messages;
  final DateTime createdAt;
  final DateTime updatedAt;

  Ticket({
    this.id = '',
    this.ticketId = '',
    this.customerId = '',
    this.customerName = '',
    this.subject = '',
    this.category = 'general',
    this.status = 'open',
    this.priority = 'medium',
    this.relatedIssueId = '',
    this.source = 'manual',
    this.messages = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      ticketId: json['ticketId'] ?? '',
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      subject: json['subject'] ?? '',
      category: json['category'] ?? 'general',
      status: json['status'] ?? 'open',
      priority: json['priority'] ?? 'medium',
      relatedIssueId: json['relatedIssueId'] ?? '',
      source: json['source'] ?? 'manual',
      messages: ((json['messages'] as List?) ?? const [])
          .map((m) => TicketMessage.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      createdAt: _parseDate(json['createdAt']),
      updatedAt: _parseDate(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) '_id': id,
        'ticketId': ticketId,
        'customerId': customerId,
        'customerName': customerName,
        'subject': subject,
        'category': category,
        'status': status,
        'priority': priority,
        'relatedIssueId': relatedIssueId,
        'source': source,
        'messages': messages.map((m) => m.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  Ticket copyWith({
    String? subject,
    String? category,
    String? status,
    String? priority,
    List<TicketMessage>? messages,
  }) {
    return Ticket(
      id: id,
      ticketId: ticketId,
      customerId: customerId,
      customerName: customerName,
      subject: subject ?? this.subject,
      category: category ?? this.category,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      relatedIssueId: relatedIssueId,
      source: source,
      messages: messages ?? this.messages,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

/// Parse dates from ISO string / millis (REST API shape).
DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
