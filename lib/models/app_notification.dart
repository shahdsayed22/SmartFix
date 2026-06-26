/// In-app notification — mirrors Mongo `Notification` schema (§4).
///
/// Named `AppNotification` to avoid clashing with Flutter/OS notification types.
/// `role` ∈ {customer, worker, admin}; `tone` ∈ {info, success, warning, danger}.
/// `type` is an event key (§7).
class AppNotification {
  final String id; // Mongo _id (if present)
  final String userId;
  final String role;
  final String type; // event key (§7)
  final String title;
  final String body;
  final String icon;
  final String tone;
  final String relatedId;
  final bool read;
  final DateTime createdAt;

  AppNotification({
    this.id = '',
    this.userId = '',
    this.role = 'customer',
    this.type = '',
    this.title = '',
    this.body = '',
    this.icon = '',
    this.tone = 'info',
    this.relatedId = '',
    this.read = false,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      userId: json['userId'] ?? '',
      role: json['role'] ?? 'customer',
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      icon: json['icon'] ?? '',
      tone: json['tone'] ?? 'info',
      relatedId: (json['relatedId'] ?? '').toString(),
      read: json['read'] ?? false,
      createdAt: _parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) '_id': id,
        'userId': userId,
        'role': role,
        'type': type,
        'title': title,
        'body': body,
        'icon': icon,
        'tone': tone,
        'relatedId': relatedId,
        'read': read,
        'createdAt': createdAt.toIso8601String(),
      };

  AppNotification copyWith({bool? read}) {
    return AppNotification(
      id: id,
      userId: userId,
      role: role,
      type: type,
      title: title,
      body: body,
      icon: icon,
      tone: tone,
      relatedId: relatedId,
      read: read ?? this.read,
      createdAt: createdAt,
    );
  }
}

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
