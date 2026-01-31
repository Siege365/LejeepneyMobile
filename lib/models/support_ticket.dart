import 'package:flutter/material.dart';

/// Enum for ticket types
enum TicketType {
  general('general'),
  technical('technical'),
  billing('billing'),
  feedback('feedback'),
  bug('bug');

  final String value;
  const TicketType(this.value);

  static TicketType fromString(String value) {
    return TicketType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => TicketType.general,
    );
  }

  String get displayName {
    switch (this) {
      case TicketType.general:
        return 'General Inquiry';
      case TicketType.technical:
        return 'Technical Issue';
      case TicketType.billing:
        return 'Billing';
      case TicketType.feedback:
        return 'Feedback';
      case TicketType.bug:
        return 'Bug Report';
    }
  }
}

/// Enum for ticket priority
enum TicketPriority {
  low('low'),
  medium('medium'),
  high('high');

  final String value;
  const TicketPriority(this.value);

  static TicketPriority fromString(String value) {
    return TicketPriority.values.firstWhere(
      (priority) => priority.value == value,
      orElse: () => TicketPriority.medium,
    );
  }

  String get displayName {
    switch (this) {
      case TicketPriority.low:
        return 'Low';
      case TicketPriority.medium:
        return 'Medium';
      case TicketPriority.high:
        return 'High';
    }
  }

  Color get color {
    switch (this) {
      case TicketPriority.low:
        return const Color(0xFF6B7280); // Gray
      case TicketPriority.medium:
        return const Color(0xFFF59E0B); // Amber
      case TicketPriority.high:
        return const Color(0xFFEF4444); // Red
    }
  }
}

/// Enum for ticket status
enum TicketStatus {
  pending('pending'),
  inProgress('in_progress'),
  resolved('resolved');

  final String value;
  const TicketStatus(this.value);

  static TicketStatus fromString(String value) {
    return TicketStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => TicketStatus.pending,
    );
  }

  String get displayName {
    switch (this) {
      case TicketStatus.pending:
        return 'Pending';
      case TicketStatus.inProgress:
        return 'In Progress';
      case TicketStatus.resolved:
        return 'Resolved';
    }
  }

  /// Badge colors as per specification
  Color get color {
    switch (this) {
      case TicketStatus.pending:
        return const Color(0xFFF59E0B); // #F59E0B - Amber
      case TicketStatus.inProgress:
        return const Color(0xFF3B82F6); // #3B82F6 - Blue
      case TicketStatus.resolved:
        return const Color(0xFF10B981); // #10B981 - Green
    }
  }

  Color get backgroundColor {
    switch (this) {
      case TicketStatus.pending:
        return const Color(0xFFFEF3C7); // Light amber
      case TicketStatus.inProgress:
        return const Color(0xFFDBEAFE); // Light blue
      case TicketStatus.resolved:
        return const Color(0xFFD1FAE5); // Light green
    }
  }

  IconData get icon {
    switch (this) {
      case TicketStatus.pending:
        return Icons.schedule;
      case TicketStatus.inProgress:
        return Icons.autorenew;
      case TicketStatus.resolved:
        return Icons.check_circle;
    }
  }
}

/// Support ticket model for list view
class SupportTicket {
  final int id;
  final String subject;
  final TicketStatus status;
  final TicketType type;
  final TicketPriority priority;
  final DateTime createdAt;
  final DateTime? updatedAt;

  SupportTicket({
    required this.id,
    required this.subject,
    required this.status,
    required this.type,
    required this.priority,
    required this.createdAt,
    this.updatedAt,
  });

  factory SupportTicket.fromJson(Map<String, dynamic> json) {
    return SupportTicket(
      id: json['id'] as int,
      subject: json['subject'] as String,
      status: TicketStatus.fromString(json['status'] as String),
      type: TicketType.fromString(json['type'] as String? ?? 'general'),
      priority: TicketPriority.fromString(
        json['priority'] as String? ?? 'medium',
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'status': status.value,
      'type': type.value,
      'priority': priority.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }
}

/// Reply in a support ticket
class TicketReply {
  final int id;
  final String message;
  final String? adminName;
  final bool isUserReply;
  final DateTime createdAt;

  TicketReply({
    required this.id,
    required this.message,
    this.adminName,
    this.isUserReply = false,
    required this.createdAt,
  });

  factory TicketReply.fromJson(Map<String, dynamic> json) {
    return TicketReply(
      id: json['id'] as int,
      message: json['message'] as String,
      adminName: json['admin_name'] as String?,
      isUserReply: json['is_user_reply'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'message': message,
      'admin_name': adminName,
      'is_user_reply': isUserReply,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Detailed support ticket with replies
class SupportTicketDetail {
  final int id;
  final String subject;
  final String message;
  final TicketStatus status;
  final TicketType type;
  final TicketPriority priority;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final List<TicketReply> replies;

  SupportTicketDetail({
    required this.id,
    required this.subject,
    required this.message,
    required this.status,
    required this.type,
    required this.priority,
    required this.createdAt,
    this.updatedAt,
    required this.replies,
  });

  factory SupportTicketDetail.fromJson(Map<String, dynamic> json) {
    final repliesJson = json['replies'] as List<dynamic>? ?? [];
    return SupportTicketDetail(
      id: json['id'] as int,
      subject: json['subject'] as String,
      message: json['message'] as String,
      status: TicketStatus.fromString(json['status'] as String),
      type: TicketType.fromString(json['type'] as String? ?? 'general'),
      priority: TicketPriority.fromString(
        json['priority'] as String? ?? 'medium',
      ),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      replies: repliesJson
          .map((reply) => TicketReply.fromJson(reply as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'message': message,
      'status': status.value,
      'type': type.value,
      'priority': priority.value,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'replies': replies.map((reply) => reply.toJson()).toList(),
    };
  }
}
