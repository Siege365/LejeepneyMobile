import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/material.dart' show IconData, Icons, Color;
import 'package:http/http.dart' as http;
import 'api_service.dart';
import '../constants/app_colors.dart';
import '../models/support_ticket.dart';

/// Service for Customer Support API integration
/// Follows Single Responsibility Principle - only handles support ticket operations
class SupportService {
  static const Duration _timeout = Duration(seconds: 30);
  static const int _maxRetries = 3;

  /// Create a new support ticket (no auth required)
  /// POST /api/v1/support/tickets
  Future<CreateTicketResult> createTicket({
    required String name,
    required String email,
    required String subject,
    required String message,
    TicketType type = TicketType.general,
    TicketPriority priority = TicketPriority.medium,
  }) async {
    final url = '${ApiService.baseUrl}/support/tickets';
    debugPrint('[SupportService] Creating ticket: $subject');
    debugPrint(
      '[SupportService] Type: ${type.value}, Priority: ${priority.value}',
    );

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'name': name,
              'email': email,
              'subject': subject,
              'message': message,
              'type': type.value,
              'priority': priority.value,
            }),
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 201 && data['success'] == true) {
        debugPrint(
          '[SupportService] Ticket created: ${data['data']['ticket_id']}',
        );
        return CreateTicketResult(
          success: true,
          ticketId: data['data']['ticket_id'] as int,
          status: data['data']['status'] as String,
          createdAt: DateTime.parse(data['data']['created_at'] as String),
          message: data['message'] as String,
        );
      } else if (response.statusCode == 422) {
        // Validation error - Laravel returns errors as {field: [messages]}
        final errors = data['errors'] as Map<String, dynamic>?;
        String errorMessage;
        if (errors != null && errors.isNotEmpty) {
          final firstError = errors.values.first;
          errorMessage = firstError is List
              ? firstError.first.toString()
              : firstError.toString();
        } else {
          errorMessage = data['message'] ?? 'Validation failed';
        }
        debugPrint('[SupportService] Validation error: $errorMessage');
        return CreateTicketResult(success: false, errorMessage: errorMessage);
      } else {
        return CreateTicketResult(
          success: false,
          errorMessage: data['message'] ?? 'Failed to create ticket',
        );
      }
    } on SocketException {
      return CreateTicketResult(
        success: false,
        errorMessage: 'No internet connection',
      );
    } on TimeoutException {
      return CreateTicketResult(
        success: false,
        errorMessage: 'Request timed out',
      );
    } catch (e) {
      debugPrint('[SupportService] Error creating ticket: $e');
      return CreateTicketResult(
        success: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Get user's tickets
  /// GET /api/v1/support/tickets?email=user@example.com&status=pending
  Future<TicketListResult> getTickets({
    required String email,
    TicketStatus? status,
    int page = 1,
    int perPage = 10,
  }) async {
    final queryParams = <String, String>{
      'email': email,
      'page': page.toString(),
      'per_page': perPage.toString(),
    };
    if (status != null) {
      queryParams['status'] = status.value;
    }

    final uri = Uri.parse(
      '${ApiService.baseUrl}/support/tickets',
    ).replace(queryParameters: queryParams);
    debugPrint('[SupportService] Fetching tickets for: $email');

    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        final response = await http
            .get(uri, headers: {'Accept': 'application/json'})
            .timeout(_timeout);

        final data = jsonDecode(response.body) as Map<String, dynamic>;

        if (response.statusCode == 200 && data['success'] == true) {
          final ticketsJson = data['data'] as List<dynamic>;
          final tickets = ticketsJson
              .map(
                (json) => SupportTicket.fromJson(json as Map<String, dynamic>),
              )
              .toList();

          final meta = data['meta'] as Map<String, dynamic>?;
          debugPrint('[SupportService] Fetched ${tickets.length} tickets');

          return TicketListResult(
            success: true,
            tickets: tickets,
            currentPage: meta?['current_page'] ?? 1,
            lastPage: meta?['last_page'] ?? 1,
            total: meta?['total'] ?? tickets.length,
          );
        } else {
          return TicketListResult(
            success: false,
            errorMessage: data['message'] ?? 'Failed to fetch tickets',
            tickets: [],
          );
        }
      } on SocketException {
        retryCount++;
        if (retryCount >= _maxRetries) {
          return TicketListResult(
            success: false,
            errorMessage: 'No internet connection',
            tickets: [],
          );
        }
        await Future.delayed(Duration(seconds: retryCount * 2));
      } on TimeoutException {
        retryCount++;
        if (retryCount >= _maxRetries) {
          return TicketListResult(
            success: false,
            errorMessage: 'Request timed out',
            tickets: [],
          );
        }
        await Future.delayed(Duration(seconds: retryCount * 2));
      } catch (e) {
        debugPrint('[SupportService] Error fetching tickets: $e');
        return TicketListResult(
          success: false,
          errorMessage: 'An unexpected error occurred',
          tickets: [],
        );
      }
    }

    return TicketListResult(
      success: false,
      errorMessage: 'Failed after multiple attempts',
      tickets: [],
    );
  }

  /// Get ticket details with replies
  /// GET /api/v1/support/tickets/{id}?email=user@example.com
  Future<TicketDetailResult> getTicketDetails({
    required int ticketId,
    required String email,
  }) async {
    final uri = Uri.parse(
      '${ApiService.baseUrl}/support/tickets/$ticketId',
    ).replace(queryParameters: {'email': email});
    debugPrint('[SupportService] Fetching ticket details: $ticketId');

    try {
      final response = await http
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(_timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final ticketData = data['data'] as Map<String, dynamic>;
        final ticket = SupportTicketDetail.fromJson(ticketData);
        debugPrint(
          '[SupportService] Ticket details fetched with ${ticket.replies.length} replies',
        );
        return TicketDetailResult(success: true, ticket: ticket);
      } else if (response.statusCode == 404) {
        return TicketDetailResult(
          success: false,
          errorMessage: 'Ticket not found',
        );
      } else {
        return TicketDetailResult(
          success: false,
          errorMessage: data['message'] ?? 'Failed to fetch ticket details',
        );
      }
    } on SocketException {
      return TicketDetailResult(
        success: false,
        errorMessage: 'No internet connection',
      );
    } on TimeoutException {
      return TicketDetailResult(
        success: false,
        errorMessage: 'Request timed out',
      );
    } catch (e) {
      debugPrint('[SupportService] Error fetching ticket details: $e');
      return TicketDetailResult(
        success: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Add follow-up message to ticket
  /// POST /api/v1/support/tickets/{id}/message?email=user@example.com
  Future<FollowUpResult> addFollowUpMessage({
    required int ticketId,
    required String email,
    required String message,
  }) async {
    final uri = Uri.parse(
      '${ApiService.baseUrl}/support/tickets/$ticketId/message',
    ).replace(queryParameters: {'email': email});
    debugPrint('[SupportService] Adding follow-up to ticket: $ticketId');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'message': message}),
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        debugPrint('[SupportService] Follow-up added successfully');
        return FollowUpResult(
          success: true,
          ticketId: data['data']['ticket_id'] as int,
          status: data['data']['status'] as String,
          message: data['message'] as String,
        );
      } else if (response.statusCode == 422) {
        final errors = data['errors'] as Map<String, dynamic>?;
        final errorMessage = errors != null
            ? errors.values.first.toString()
            : data['message'] ?? 'Validation failed';
        return FollowUpResult(success: false, errorMessage: errorMessage);
      } else {
        return FollowUpResult(
          success: false,
          errorMessage: data['message'] ?? 'Failed to add follow-up',
        );
      }
    } on SocketException {
      return FollowUpResult(
        success: false,
        errorMessage: 'No internet connection',
      );
    } on TimeoutException {
      return FollowUpResult(success: false, errorMessage: 'Request timed out');
    } catch (e) {
      debugPrint('[SupportService] Error adding follow-up: $e');
      return FollowUpResult(
        success: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  // ============================================================
  // TICKET CANCEL METHOD
  // ============================================================

  /// Cancel a support ticket
  /// PUT /api/v1/support/tickets/{id}/cancel?email=user@example.com
  Future<SimpleResult> cancelTicket({
    required int ticketId,
    required String email,
  }) async {
    final url = '${ApiService.baseUrl}/support/tickets/$ticketId/cancel';
    debugPrint('[SupportService] Cancelling ticket: $ticketId');

    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({'email': email}),
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        debugPrint('[SupportService] Ticket $ticketId cancelled');
        return SimpleResult(
          success: true,
          message: data['message'] ?? 'Ticket cancelled',
        );
      } else {
        return SimpleResult(
          success: false,
          errorMessage: data['message'] ?? 'Failed to cancel ticket',
        );
      }
    } on SocketException {
      return SimpleResult(
        success: false,
        errorMessage: 'No internet connection',
      );
    } on TimeoutException {
      return SimpleResult(success: false, errorMessage: 'Request timed out');
    } catch (e) {
      debugPrint('[SupportService] Error cancelling ticket: $e');
      return SimpleResult(
        success: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  // ============================================================
  // NOTIFICATION API METHODS
  // ============================================================

  /// Get notifications for a user
  /// GET /api/v1/support/notifications
  Future<NotificationListResult> getNotifications({
    required String email,
    bool? isRead,
    String? eventType,
    int? days,
    int perPage = 20,
    int page = 1,
  }) async {
    final queryParams = <String, String>{
      'email': email,
      'per_page': perPage.toString(),
      'page': page.toString(),
    };
    if (isRead != null) queryParams['is_read'] = isRead.toString();
    if (eventType != null) queryParams['event_type'] = eventType;
    if (days != null) queryParams['days'] = days.toString();

    final uri = Uri.parse(
      '${ApiService.baseUrl}/support/notifications',
    ).replace(queryParameters: queryParams);
    debugPrint('[SupportService] Fetching notifications for: $email');

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final notificationsJson = data['data'] as List<dynamic>;
        final notifications = notificationsJson
            .map(
              (json) =>
                  ServerNotification.fromJson(json as Map<String, dynamic>),
            )
            .toList();

        final meta = data['meta'] as Map<String, dynamic>?;
        debugPrint(
          '[SupportService] Fetched ${notifications.length} notifications',
        );

        return NotificationListResult(
          success: true,
          notifications: notifications,
          currentPage: meta?['current_page'] ?? 1,
          lastPage: meta?['last_page'] ?? 1,
          total: meta?['total'] ?? notifications.length,
          unreadCount: meta?['unread_count'] ?? 0,
        );
      } else {
        return NotificationListResult(
          success: false,
          errorMessage: data['message'] ?? 'Failed to fetch notifications',
          notifications: [],
        );
      }
    } on SocketException {
      return NotificationListResult(
        success: false,
        errorMessage: 'No internet connection',
        notifications: [],
      );
    } on TimeoutException {
      return NotificationListResult(
        success: false,
        errorMessage: 'Request timed out',
        notifications: [],
      );
    } catch (e) {
      debugPrint('[SupportService] Error fetching notifications: $e');
      return NotificationListResult(
        success: false,
        errorMessage: 'An unexpected error occurred',
        notifications: [],
      );
    }
  }

  /// Get unread notification count
  /// GET /api/v1/support/notifications/unread-count
  Future<UnreadCountResult> getUnreadCount({required String email}) async {
    final uri = Uri.parse(
      '${ApiService.baseUrl}/support/notifications/unread-count',
    ).replace(queryParameters: {'email': email});
    debugPrint('[SupportService] Fetching unread count for: $email');

    try {
      final response = await http
          .get(
            uri,
            headers: {
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        final count = data['unread_count'] as int;
        debugPrint('[SupportService] Unread count: $count');
        return UnreadCountResult(success: true, count: count);
      } else {
        return UnreadCountResult(
          success: false,
          errorMessage: data['message'] ?? 'Failed to fetch unread count',
        );
      }
    } on SocketException {
      return UnreadCountResult(
        success: false,
        errorMessage: 'No internet connection',
      );
    } on TimeoutException {
      return UnreadCountResult(
        success: false,
        errorMessage: 'Request timed out',
      );
    } catch (e) {
      debugPrint('[SupportService] Error fetching unread count: $e');
      return UnreadCountResult(
        success: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Mark a notification as read
  /// PUT /api/v1/support/notifications/{id}/read
  Future<SimpleResult> markNotificationAsRead({
    required int notificationId,
    required String email,
  }) async {
    final uri = Uri.parse(
      '${ApiService.baseUrl}/support/notifications/$notificationId/read',
    ).replace(queryParameters: {'email': email});
    debugPrint('[SupportService] Marking notification $notificationId as read');

    try {
      final response = await http
          .put(
            uri,
            headers: {
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return SimpleResult(success: true, message: data['message']);
      } else {
        return SimpleResult(
          success: false,
          errorMessage: data['message'] ?? 'Failed to mark as read',
        );
      }
    } on SocketException {
      return SimpleResult(
        success: false,
        errorMessage: 'No internet connection',
      );
    } on TimeoutException {
      return SimpleResult(success: false, errorMessage: 'Request timed out');
    } catch (e) {
      debugPrint('[SupportService] Error marking as read: $e');
      return SimpleResult(
        success: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Mark all notifications as read
  /// PUT /api/v1/support/notifications/mark-all-read
  Future<MarkAllReadResult> markAllNotificationsAsRead({
    required String email,
  }) async {
    final uri = Uri.parse(
      '${ApiService.baseUrl}/support/notifications/mark-all-read',
    ).replace(queryParameters: {'email': email});
    debugPrint(
      '[SupportService] Marking all notifications as read for: $email',
    );

    try {
      final response = await http
          .put(
            uri,
            headers: {
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return MarkAllReadResult(
          success: true,
          message: data['message'],
          updatedCount: data['updated_count'] ?? 0,
        );
      } else {
        return MarkAllReadResult(
          success: false,
          errorMessage: data['message'] ?? 'Failed to mark all as read',
        );
      }
    } on SocketException {
      return MarkAllReadResult(
        success: false,
        errorMessage: 'No internet connection',
      );
    } on TimeoutException {
      return MarkAllReadResult(
        success: false,
        errorMessage: 'Request timed out',
      );
    } catch (e) {
      debugPrint('[SupportService] Error marking all as read: $e');
      return MarkAllReadResult(
        success: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }

  /// Delete a notification
  /// DELETE /api/v1/support/notifications/{id}
  Future<SimpleResult> deleteNotification({
    required int notificationId,
    required String email,
  }) async {
    final uri = Uri.parse(
      '${ApiService.baseUrl}/support/notifications/$notificationId',
    ).replace(queryParameters: {'email': email});
    debugPrint('[SupportService] Deleting notification $notificationId');

    try {
      final response = await http
          .delete(
            uri,
            headers: {
              'Accept': 'application/json',
              'ngrok-skip-browser-warning': 'true',
            },
          )
          .timeout(_timeout);

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200 && data['success'] == true) {
        return SimpleResult(success: true, message: data['message']);
      } else {
        return SimpleResult(
          success: false,
          errorMessage: data['message'] ?? 'Failed to delete notification',
        );
      }
    } on SocketException {
      return SimpleResult(
        success: false,
        errorMessage: 'No internet connection',
      );
    } on TimeoutException {
      return SimpleResult(success: false, errorMessage: 'Request timed out');
    } catch (e) {
      debugPrint('[SupportService] Error deleting notification: $e');
      return SimpleResult(
        success: false,
        errorMessage: 'An unexpected error occurred',
      );
    }
  }
}

/// Result of creating a ticket
class CreateTicketResult {
  final bool success;
  final int? ticketId;
  final String? status;
  final DateTime? createdAt;
  final String? message;
  final String? errorMessage;

  CreateTicketResult({
    required this.success,
    this.ticketId,
    this.status,
    this.createdAt,
    this.message,
    this.errorMessage,
  });
}

/// Result of fetching ticket list
class TicketListResult {
  final bool success;
  final List<SupportTicket> tickets;
  final int currentPage;
  final int lastPage;
  final int total;
  final String? errorMessage;

  TicketListResult({
    required this.success,
    required this.tickets,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.errorMessage,
  });
}

/// Result of fetching ticket details
class TicketDetailResult {
  final bool success;
  final SupportTicketDetail? ticket;
  final String? errorMessage;

  TicketDetailResult({required this.success, this.ticket, this.errorMessage});
}

/// Result of adding follow-up message
class FollowUpResult {
  final bool success;
  final int? ticketId;
  final String? status;
  final String? message;
  final String? errorMessage;

  FollowUpResult({
    required this.success,
    this.ticketId,
    this.status,
    this.message,
    this.errorMessage,
  });
}

/// Result of fetching notifications
class NotificationListResult {
  final bool success;
  final List<ServerNotification> notifications;
  final int currentPage;
  final int lastPage;
  final int total;
  final int unreadCount;
  final String? errorMessage;

  NotificationListResult({
    required this.success,
    required this.notifications,
    this.currentPage = 1,
    this.lastPage = 1,
    this.total = 0,
    this.unreadCount = 0,
    this.errorMessage,
  });
}

/// Result of fetching unread count
class UnreadCountResult {
  final bool success;
  final int count;
  final String? errorMessage;

  UnreadCountResult({required this.success, this.count = 0, this.errorMessage});
}

/// Result of marking all as read
class MarkAllReadResult {
  final bool success;
  final String? message;
  final int updatedCount;
  final String? errorMessage;

  MarkAllReadResult({
    required this.success,
    this.message,
    this.updatedCount = 0,
    this.errorMessage,
  });
}

/// Simple result for operations with just success/failure
class SimpleResult {
  final bool success;
  final String? message;
  final String? errorMessage;

  SimpleResult({required this.success, this.message, this.errorMessage});
}

/// Server notification model (from API)
class ServerNotification {
  final int id;
  final int ticketId;
  final String userEmail;
  final String eventType;
  final String title;
  final String message;
  final Map<String, dynamic>? metadata;
  final bool isRead;
  final DateTime? readAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final ServerNotificationTicket? ticket;

  ServerNotification({
    required this.id,
    required this.ticketId,
    required this.userEmail,
    required this.eventType,
    required this.title,
    required this.message,
    this.metadata,
    required this.isRead,
    this.readAt,
    required this.createdAt,
    required this.updatedAt,
    this.ticket,
  });

  factory ServerNotification.fromJson(Map<String, dynamic> json) {
    return ServerNotification(
      id: json['id'] as int,
      ticketId: json['ticket_id'] as int,
      userEmail: json['user_email'] as String,
      eventType: json['event_type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      metadata: json['metadata'] as Map<String, dynamic>?,
      isRead: json['is_read'] as bool? ?? false,
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      ticket: json['ticket'] != null
          ? ServerNotificationTicket.fromJson(
              json['ticket'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  /// Get icon based on event type
  IconData get icon {
    switch (eventType) {
      case 'created':
        return Icons.add_circle_outline;
      case 'admin_message':
        return Icons.reply;
      case 'status_changed':
        return Icons.sync;
      case 'resolved':
        return Icons.check_circle_outline;
      default:
        return Icons.notifications;
    }
  }

  /// Get icon color based on event type
  Color get iconColor {
    switch (eventType) {
      case 'created':
        return const Color(0xFF3B82F6); // Blue
      case 'admin_message':
        return AppColors.success; // Green
      case 'status_changed':
        return const Color(0xFFF59E0B); // Amber
      case 'resolved':
        return AppColors.success; // Green
      default:
        return const Color(0xFF6B7280); // Gray
    }
  }

  /// Get relative time string
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
    }
  }
}

/// Ticket info embedded in notification
class ServerNotificationTicket {
  final int id;
  final String subject;
  final String status;

  ServerNotificationTicket({
    required this.id,
    required this.subject,
    required this.status,
  });

  factory ServerNotificationTicket.fromJson(Map<String, dynamic> json) {
    return ServerNotificationTicket(
      id: json['id'] as int,
      subject: json['subject'] as String,
      status: json['status'] as String,
    );
  }
}
