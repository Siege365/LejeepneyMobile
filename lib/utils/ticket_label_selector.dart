import '../models/support_ticket.dart';

/// Smart ticket label selection algorithm
/// Follows Single Responsibility Principle - only handles label selection logic
class TicketLabelSelector {
  /// Quick action types that map to ticket categories
  static const String actionBug = 'bug';
  static const String actionTechnical = 'technical';
  static const String actionFeedback = 'feedback';
  static const String actionGeneral = 'general';

  /// Common topic identifiers
  static const String topicRouteNotWorking = 'route_not_working';
  static const String topicIncorrectFare = 'incorrect_fare';
  static const String topicLocationIssues = 'location_issues';
  static const String topicAppPerformance = 'app_performance';

  /// Result of label selection containing type and priority
  final TicketType type;
  final TicketPriority priority;
  final String? autoSelectReason;

  const TicketLabelSelector._({
    required this.type,
    required this.priority,
    this.autoSelectReason,
  });

  /// Select labels based on quick action button pressed
  ///
  /// - Bug Report: type=bug, priority=medium/high
  /// - Technical: type=technical, priority=medium/high
  /// - Feedback: type=feedback, priority=low
  /// - General: type=general, priority=low
  factory TicketLabelSelector.fromQuickAction(String actionType) {
    switch (actionType.toLowerCase()) {
      case actionBug:
        return const TicketLabelSelector._(
          type: TicketType.bug,
          priority: TicketPriority.medium,
          autoSelectReason: 'Bug reports are prioritized for quick resolution',
        );

      case actionTechnical:
        return const TicketLabelSelector._(
          type: TicketType.technical,
          priority: TicketPriority.medium,
          autoSelectReason: 'Technical issues require investigation',
        );

      case actionFeedback:
        return const TicketLabelSelector._(
          type: TicketType.feedback,
          priority: TicketPriority.low,
          autoSelectReason: 'Feedback helps us improve',
        );

      case actionGeneral:
      default:
        return const TicketLabelSelector._(
          type: TicketType.general,
          priority: TicketPriority.low,
          autoSelectReason: 'General inquiry',
        );
    }
  }

  /// Select labels based on common help topics
  ///
  /// - Route not working → Bug Report
  /// - Incorrect fare → Billing
  /// - Location issues → Technical Issue
  /// - App performance → Technical Issue
  factory TicketLabelSelector.fromCommonTopic(String topicId) {
    switch (topicId.toLowerCase()) {
      case topicRouteNotWorking:
        return const TicketLabelSelector._(
          type: TicketType.bug,
          priority: TicketPriority.high,
          autoSelectReason: 'Route issues affect your navigation experience',
        );

      case topicIncorrectFare:
        return const TicketLabelSelector._(
          type: TicketType.billing,
          priority: TicketPriority.low,
          autoSelectReason: 'Billing inquiries are reviewed by our team',
        );

      case topicLocationIssues:
        return const TicketLabelSelector._(
          type: TicketType.technical,
          priority: TicketPriority.high,
          autoSelectReason: 'Location issues require immediate attention',
        );

      case topicAppPerformance:
        return const TicketLabelSelector._(
          type: TicketType.technical,
          priority: TicketPriority.medium,
          autoSelectReason: 'Performance issues will be investigated',
        );

      default:
        return const TicketLabelSelector._(
          type: TicketType.general,
          priority: TicketPriority.low,
          autoSelectReason: 'General inquiry',
        );
    }
  }

  /// Analyze message content to suggest appropriate labels
  /// Uses keyword matching to detect issue type
  factory TicketLabelSelector.fromMessageContent(String message) {
    final lowerMessage = message.toLowerCase();

    // High priority keywords (bugs, crashes, not working)
    final bugKeywords = [
      'crash',
      'not working',
      'broken',
      'error',
      'bug',
      'fail',
      'stuck',
      'freeze',
      'won\'t load',
      'doesn\'t work',
    ];

    // Technical keywords
    final technicalKeywords = [
      'slow',
      'performance',
      'gps',
      'location',
      'map',
      'loading',
      'timeout',
      'connection',
      'sync',
    ];

    // Billing keywords
    final billingKeywords = [
      'fare',
      'price',
      'cost',
      'payment',
      'charge',
      'fee',
      'wrong amount',
      'incorrect fare',
      'overcharge',
    ];

    // Feedback keywords
    final feedbackKeywords = [
      'suggest',
      'feature',
      'improve',
      'would be nice',
      'wish',
      'feedback',
      'idea',
      'request',
    ];

    // Check for bug keywords first (highest priority)
    for (final keyword in bugKeywords) {
      if (lowerMessage.contains(keyword)) {
        return const TicketLabelSelector._(
          type: TicketType.bug,
          priority: TicketPriority.high,
          autoSelectReason: 'Detected potential bug or error in your message',
        );
      }
    }

    // Check for billing keywords
    for (final keyword in billingKeywords) {
      if (lowerMessage.contains(keyword)) {
        return const TicketLabelSelector._(
          type: TicketType.billing,
          priority: TicketPriority.low,
          autoSelectReason: 'Detected billing-related inquiry',
        );
      }
    }

    // Check for technical keywords
    for (final keyword in technicalKeywords) {
      if (lowerMessage.contains(keyword)) {
        return const TicketLabelSelector._(
          type: TicketType.technical,
          priority: TicketPriority.medium,
          autoSelectReason: 'Detected technical issue in your message',
        );
      }
    }

    // Check for feedback keywords
    for (final keyword in feedbackKeywords) {
      if (lowerMessage.contains(keyword)) {
        return const TicketLabelSelector._(
          type: TicketType.feedback,
          priority: TicketPriority.low,
          autoSelectReason: 'Detected feedback or suggestion',
        );
      }
    }

    // Default fallback
    return const TicketLabelSelector._(
      type: TicketType.general,
      priority: TicketPriority.medium,
      autoSelectReason: null,
    );
  }

  /// Determine if priority should be escalated based on urgency words
  static TicketPriority escalatePriority(
    TicketPriority currentPriority,
    String message,
  ) {
    final lowerMessage = message.toLowerCase();

    final urgentKeywords = [
      'urgent',
      'asap',
      'immediately',
      'emergency',
      'critical',
      'can\'t use',
      'completely broken',
    ];

    for (final keyword in urgentKeywords) {
      if (lowerMessage.contains(keyword)) {
        // Escalate to high if urgent keywords found
        return TicketPriority.high;
      }
    }

    return currentPriority;
  }

  @override
  String toString() {
    return 'TicketLabelSelector(type: ${type.displayName}, priority: ${priority.displayName}, reason: $autoSelectReason)';
  }
}
