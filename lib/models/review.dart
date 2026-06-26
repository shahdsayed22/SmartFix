/// Review model — rating after job completion. Mirrors Mongo `Review` (§4).
///
/// One review per `issueId` (unique on the server → no duplicate ratings).
class Review {
  final String id; // Mongo _id (if present)
  final String issueId; // unique
  final String technicianId;
  final String technicianName;
  final String customerId;
  final String customerName;
  final int rating; // 1..5
  final List<String> tags;
  final String comment;
  final String category;
  final DateTime createdAt;

  Review({
    this.id = '',
    this.issueId = '',
    this.technicianId = '',
    this.technicianName = '',
    this.customerId = '',
    this.customerName = '',
    this.rating = 0,
    this.tags = const [],
    this.comment = '',
    this.category = '',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      issueId: json['issueId'] ?? '',
      technicianId: json['technicianId'] ?? '',
      technicianName: json['technicianName'] ?? '',
      customerId: json['customerId'] ?? '',
      customerName: json['customerName'] ?? '',
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      tags: List<String>.from(json['tags'] ?? const []),
      comment: json['comment'] ?? '',
      category: json['category'] ?? '',
      createdAt: _parseDate(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id.isNotEmpty) '_id': id,
        'issueId': issueId,
        'technicianId': technicianId,
        'technicianName': technicianName,
        'customerId': customerId,
        'customerName': customerName,
        'rating': rating,
        'tags': tags,
        'comment': comment,
        'category': category,
        'createdAt': createdAt.toIso8601String(),
      };
}

DateTime _parseDate(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
  return DateTime.now();
}
