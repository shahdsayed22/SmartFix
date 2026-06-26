import 'dart:async';
import '../models/issue_model.dart';
import 'api_service.dart';

/// Service for managing issues/jobs.
/// Uses the Next.js dashboard REST API (MongoDB) as the data source,
/// bridging the Flutter app and the admin dashboard.
class JobService {
  final ApiService _api = ApiService();

  /// Create a new issue — posts to the dashboard API so it's
  /// immediately visible on both the mobile app and the web dashboard.
  Future<void> createIssue(
    Issue issue, {
    String? customerEmail,
    String? customerPhone,
  }) async {
    await _api.createIssue(
      issue.toApiMap(
        customerEmail: customerEmail,
        customerPhone: customerPhone,
      ),
    );
  }

  /// Get issues for a specific customer.
  /// Filters server-side by customerId for performance.
  Future<List<Issue>> getCustomerIssues(String customerId) async {
    final data = await _api.getIssues(customerId: customerId);
    final issues = data.map((m) => _issueFromApiMap(m)).toList();
    issues.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return issues;
  }

  /// Get available jobs for a worker based on their skills.
  Future<List<Issue>> getWorkerJobs(List<String> skills) async {
    final data = await _api.getIssues();
    final issues =
        data
            .where((m) {
              final category = m['category'] as String? ?? '';
              final status = m['status'] as String? ?? '';
              return skills.contains(category) &&
                  ['pending', 'assigned', 'inProgress'].contains(status);
            })
            .map((m) => _issueFromApiMap(m))
            .toList();
    issues.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return issues;
  }

  /// Get assigned jobs for a specific worker.
  Future<List<Issue>> getAssignedJobs(String workerId) async {
    final data = await _api.getIssues();
    final issues =
        data
            .where((m) => m['assignedTechnicianId'] == workerId)
            .map((m) => _issueFromApiMap(m))
            .toList();
    issues.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return issues;
  }

  /// Get a single issue by ID.
  Future<Issue> getIssue(String issueId) async {
    final data = await _api.getIssues();
    final match = data.firstWhere(
      (m) => m['id'] == issueId || m['_id'] == issueId,
      orElse: () => throw Exception('Issue not found'),
    );
    return _issueFromApiMap(match);
  }

  /// Worker accepts a job.
  Future<void> acceptJob(
    String issueId,
    String workerId,
    String workerName,
  ) async {
    await _api.updateIssue(issueId, {
      'assignedTechnicianId': workerId,
      'assignedTechnicianName': workerName,
      'status': 'assigned',
    });
  }

  /// Update issue status.
  Future<void> updateIssueStatus(String issueId, IssueStatus status) async {
    await _api.updateIssue(issueId, {'status': status.name});
  }

  /// Cancel an issue.
  Future<void> cancelIssue(String issueId) async {
    await _api.updateIssue(issueId, {'status': 'cancelled'});
  }

  /// Get customer stats (total, pending, inProgress, completed).
  Future<Map<String, int>> getCustomerStats(String customerId) async {
    final issues = await getCustomerIssues(customerId);

    final stats = <String, int>{
      'total': issues.length,
      'pending': 0,
      'inProgress': 0,
      'completed': 0,
    };

    for (final issue in issues) {
      final status = issue.status;
      if (status == IssueStatus.pending || status == IssueStatus.assigned) {
        stats['pending'] = (stats['pending'] ?? 0) + 1;
      } else if (status == IssueStatus.inProgress) {
        stats['inProgress'] = (stats['inProgress'] ?? 0) + 1;
      } else if (status == IssueStatus.completed) {
        stats['completed'] = (stats['completed'] ?? 0) + 1;
      }
    }

    return stats;
  }

  /// Convert an API response map into an Issue model.
  /// Handles both MongoDB's `_id` field and our custom `id` field.
  Issue _issueFromApiMap(Map<String, dynamic> map) {
    // Normalize the id field
    final normalized = Map<String, dynamic>.from(map);
    if (normalized['id'] == null && normalized['_id'] != null) {
      normalized['id'] = normalized['_id'].toString();
    }
    // Parse dates from ISO strings (MongoDB) instead of Firestore Timestamps
    if (normalized['createdAt'] is String) {
      normalized['createdAt'] =
          DateTime.tryParse(normalized['createdAt']) ?? DateTime.now();
    }
    if (normalized['updatedAt'] is String) {
      normalized['updatedAt'] =
          DateTime.tryParse(normalized['updatedAt']) ?? DateTime.now();
    }
    return Issue.fromMap(normalized);
  }
}
