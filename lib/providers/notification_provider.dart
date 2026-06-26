import 'package:flutter/foundation.dart';

import '../models/app_notification.dart';
import '../services/api_service.dart';

/// Holds the current user's in-app notifications and the unread count.
///
/// Registered globally (in `main.dart`) so the app shell can surface the
/// unread badge and the [NotificationsScreen] can read/refresh the list.
/// All mutations call the backend first, then update the in-memory cache and
/// notify listeners.
class NotificationProvider extends ChangeNotifier {
  NotificationProvider({ApiService? api}) : _api = api ?? ApiService();

  final ApiService _api;

  List<AppNotification> _items = const <AppNotification>[];
  bool _loading = false;
  Object? _error;

  /// All notifications, newest first.
  List<AppNotification> get items => _items;

  /// Count of unread notifications.
  int get unread => _items.where((n) => !n.read).length;

  bool get isLoading => _loading;
  Object? get error => _error;

  /// Fetch the notifications for [userId] from the backend.
  Future<void> load(String userId) async {
    if (userId.isEmpty) {
      _items = const <AppNotification>[];
      _error = null;
      _loading = false;
      notifyListeners();
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final raw = await _api.getNotifications(userId);
      final list = raw.map(AppNotification.fromJson).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      _items = list;
      _error = null;
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Mark a single notification as read (optimistic, reverts on failure).
  Future<void> markRead(String id) async {
    if (id.isEmpty) return;
    final idx = _items.indexWhere((n) => n.id == id);
    if (idx == -1 || _items[idx].read) return;

    final previous = _items[idx];
    _items[idx] = previous.copyWith(read: true);
    notifyListeners();

    try {
      await _api.markNotificationRead(id: id);
    } catch (_) {
      _items[idx] = previous;
      notifyListeners();
    }
  }

  /// Mark every notification for [userId] as read (optimistic).
  Future<void> markAllRead(String userId) async {
    if (userId.isEmpty || unread == 0) return;

    final previous = _items;
    _items = _items.map((n) => n.read ? n : n.copyWith(read: true)).toList();
    notifyListeners();

    try {
      await _api.markNotificationRead(userId: userId);
    } catch (_) {
      _items = previous;
      notifyListeners();
    }
  }
}
