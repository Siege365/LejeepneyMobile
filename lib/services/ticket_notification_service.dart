import 'dart:async';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'support_service.dart';
import 'auth_service.dart';

/// Service for managing ticket notifications
/// Fetches from server API and uses local storage as cache
/// Follows Single Responsibility Principle - only handles notification management
class TicketNotificationService {
  static TicketNotificationService? _instance;
  final SupportService _supportService = SupportService();
  final AuthService _authService = AuthService();

  SharedPreferences? _prefs;
  List<ServerNotification> _cachedNotifications = [];
  int _unreadCount = 0;
  bool _isInitialized = false;

  // Polling
  Timer? _pollingTimer;
  static const Duration _backgroundPollingInterval = Duration(seconds: 60);

  // Listeners for UI updates
  final List<void Function(int)> _unreadCountListeners = [];

  TicketNotificationService._();

  static TicketNotificationService get instance {
    _instance ??= TicketNotificationService._();
    return _instance!;
  }

  bool get isInitialized => _isInitialized;
  int get unreadCount => _unreadCount;
  List<ServerNotification> get notifications =>
      List.unmodifiable(_cachedNotifications);

  /// Initialize the service
  Future<void> init() async {
    if (_isInitialized) return;

    _prefs = await SharedPreferences.getInstance();
    _unreadCount = _prefs?.getInt('notification_unread_count') ?? 0;
    _isInitialized = true;

    debugPrint(
      '[TicketNotificationService] Initialized with cached unread count: $_unreadCount',
    );
  }

  /// Add listener for unread count changes
  void addUnreadCountListener(void Function(int) listener) {
    _unreadCountListeners.add(listener);
  }

  /// Remove listener
  void removeUnreadCountListener(void Function(int) listener) {
    _unreadCountListeners.remove(listener);
  }

  /// Notify all listeners of unread count change
  void _notifyListeners() {
    for (final listener in _unreadCountListeners) {
      listener(_unreadCount);
    }
  }

  /// Fetch notifications from server
  Future<List<ServerNotification>> fetchNotifications({
    bool? isRead,
    String? eventType,
    int? days,
    int perPage = 20,
    int page = 1,
  }) async {
    final user = await _authService.getCachedUser();
    if (user == null) {
      debugPrint('[TicketNotificationService] No user logged in');
      return _cachedNotifications;
    }

    final result = await _supportService.getNotifications(
      email: user.email,
      isRead: isRead,
      eventType: eventType,
      days: days,
      perPage: perPage,
      page: page,
    );

    if (result.success) {
      _cachedNotifications = result.notifications;
      _unreadCount = result.unreadCount;
      await _prefs?.setInt('notification_unread_count', _unreadCount);
      _notifyListeners();

      debugPrint(
        '[TicketNotificationService] Fetched ${result.notifications.length} notifications, unread: $_unreadCount',
      );
      return result.notifications;
    } else {
      debugPrint(
        '[TicketNotificationService] Failed to fetch: ${result.errorMessage}',
      );
      return _cachedNotifications;
    }
  }

  /// Fetch unread count only (lightweight)
  Future<int> fetchUnreadCount() async {
    final user = await _authService.getCachedUser();
    if (user == null) return _unreadCount;

    final result = await _supportService.getUnreadCount(email: user.email);

    if (result.success) {
      final previousCount = _unreadCount;
      _unreadCount = result.count;
      await _prefs?.setInt('notification_unread_count', _unreadCount);

      if (_unreadCount != previousCount) {
        _notifyListeners();
      }

      debugPrint('[TicketNotificationService] Unread count: $_unreadCount');
    }

    return _unreadCount;
  }

  /// Mark a single notification as read
  Future<bool> markAsRead(int notificationId) async {
    final user = await _authService.getCachedUser();
    if (user == null) return false;

    final result = await _supportService.markNotificationAsRead(
      notificationId: notificationId,
      email: user.email,
    );

    if (result.success) {
      // Update local cache
      final index = _cachedNotifications.indexWhere(
        (n) => n.id == notificationId,
      );
      if (index != -1 && !_cachedNotifications[index].isRead) {
        _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
        await _prefs?.setInt('notification_unread_count', _unreadCount);
        _notifyListeners();
      }
      debugPrint(
        '[TicketNotificationService] Marked notification $notificationId as read',
      );
      return true;
    }

    return false;
  }

  /// Mark all notifications as read
  Future<bool> markAllAsRead() async {
    final user = await _authService.getCachedUser();
    if (user == null) return false;

    final result = await _supportService.markAllNotificationsAsRead(
      email: user.email,
    );

    if (result.success) {
      _unreadCount = 0;
      await _prefs?.setInt('notification_unread_count', 0);
      _notifyListeners();
      debugPrint(
        '[TicketNotificationService] Marked all as read (${result.updatedCount} updated)',
      );
      return true;
    }

    return false;
  }

  /// Delete a notification
  Future<bool> deleteNotification(int notificationId) async {
    final user = await _authService.getCachedUser();
    if (user == null) return false;

    final result = await _supportService.deleteNotification(
      notificationId: notificationId,
      email: user.email,
    );

    if (result.success) {
      // Remove from local cache
      final notification = _cachedNotifications.firstWhere(
        (n) => n.id == notificationId,
        orElse: () => ServerNotification(
          id: 0,
          ticketId: 0,
          userEmail: '',
          eventType: '',
          title: '',
          message: '',
          isRead: true,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (!notification.isRead) {
        _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
        await _prefs?.setInt('notification_unread_count', _unreadCount);
        _notifyListeners();
      }

      _cachedNotifications.removeWhere((n) => n.id == notificationId);
      debugPrint(
        '[TicketNotificationService] Deleted notification $notificationId',
      );
      return true;
    }

    return false;
  }

  /// Start background polling for notifications
  void startBackgroundPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_backgroundPollingInterval, (_) {
      fetchUnreadCount();
    });
    debugPrint('[TicketNotificationService] Started background polling');
  }

  /// Stop background polling
  void stopBackgroundPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    debugPrint('[TicketNotificationService] Stopped background polling');
  }

  /// Get cached unread count (no API call)
  int getCachedUnreadCount() {
    return _unreadCount;
  }

  /// Clear local cache
  Future<void> clearCache() async {
    _cachedNotifications.clear();
    _unreadCount = 0;
    await _prefs?.remove('notification_unread_count');
    _notifyListeners();
  }

  /// Dispose resources
  void dispose() {
    stopBackgroundPolling();
    _unreadCountListeners.clear();
  }
}
