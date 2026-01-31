import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;
import 'api_service.dart';
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
        // Validation error
        final errors = data['errors'] as Map<String, dynamic>?;
        final errorMessage = errors != null
            ? errors.values.first.toString()
            : data['message'] ?? 'Validation failed';
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
