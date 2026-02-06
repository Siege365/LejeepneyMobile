import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/support_ticket.dart';
import '../../services/support_service.dart';
import '../../services/recent_activity_service.dart';

/// Screen to display ticket details and real-time conversation chat
/// Supports auto-refresh polling for new admin messages
class TicketDetailScreen extends StatefulWidget {
  final int ticketId;
  final String userEmail;

  const TicketDetailScreen({
    super.key,
    required this.ticketId,
    required this.userEmail,
  });

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen>
    with WidgetsBindingObserver {
  final SupportService _supportService = SupportService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  SupportTicketDetail? _ticket;
  bool _isLoading = true;
  bool _isSending = false;
  bool _hasNewMessages = false;
  String? _errorMessage;

  // Auto-refresh polling
  Timer? _pollingTimer;
  static const Duration _pollingInterval = Duration(seconds: 15);
  DateTime? _lastUpdate;
  int _previousReplyCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadTicketDetails();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPolling();
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Resume/pause polling based on app state
    if (state == AppLifecycleState.resumed) {
      _loadTicketDetails();
      _startPolling();
    } else if (state == AppLifecycleState.paused) {
      _stopPolling();
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(_pollingInterval, (_) {
      if (mounted && _ticket?.status != TicketStatus.resolved) {
        _checkForNewMessages();
      }
    });
  }

  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  Future<void> _checkForNewMessages() async {
    if (_ticket == null) return;

    final result = await _supportService.getTicketDetails(
      ticketId: widget.ticketId,
      email: widget.userEmail,
    );

    if (mounted && result.success && result.ticket != null) {
      final newReplyCount = result.ticket!.replies.length;
      if (newReplyCount > _previousReplyCount) {
        // New message detected
        // Backend automatically creates notification for admin replies

        setState(() {
          _ticket = result.ticket;
          _hasNewMessages = true;
          _previousReplyCount = newReplyCount;
          _lastUpdate = DateTime.now();
        });
        _scrollToBottom();
        _showNewMessageNotification();
      } else if (result.ticket!.status != _ticket!.status) {
        // Backend automatically creates notification for status changes
        // Record in recent activity
        await RecentActivityService.addTicketStatusChanged(
          userId: widget.userEmail,
          ticketId: widget.ticketId,
          subject: result.ticket!.subject,
          newStatus: result.ticket!.status.displayName,
        );
        setState(() {
          _ticket = result.ticket;
          _lastUpdate = DateTime.now();
        });
        _showStatusChangeNotification(result.ticket!.status);
      }
    }
  }

  void _showNewMessageNotification() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.message, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('New message from support'),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showStatusChangeNotification(TicketStatus newStatus) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(newStatus.icon, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text('Ticket status changed to ${newStatus.displayName}'),
          ],
        ),
        backgroundColor: newStatus.color,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadTicketDetails() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await _supportService.getTicketDetails(
      ticketId: widget.ticketId,
      email: widget.userEmail,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _ticket = result.ticket;
          _previousReplyCount = result.ticket?.replies.length ?? 0;
          _lastUpdate = DateTime.now();
        } else {
          _errorMessage = result.errorMessage;
        }
      });

      // Scroll to bottom after loading
      if (_ticket != null && _ticket!.replies.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendFollowUp() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) {
      _showValidationError('Please enter a message');
      return;
    }
    if (message.length < 10) {
      _showValidationError('Message must be at least 10 characters');
      return;
    }

    setState(() {
      _isSending = true;
    });

    // Optimistic UI update - add message immediately
    final optimisticReply = TicketReply(
      id: -1, // Temporary ID
      message: message,
      isUserReply: true,
      createdAt: DateTime.now(),
    );

    setState(() {
      _ticket = SupportTicketDetail(
        id: _ticket!.id,
        subject: _ticket!.subject,
        message: _ticket!.message,
        status: _ticket!.status,
        type: _ticket!.type,
        priority: _ticket!.priority,
        createdAt: _ticket!.createdAt,
        updatedAt: DateTime.now(),
        replies: [..._ticket!.replies, optimisticReply],
      );
    });

    _messageController.clear();
    _messageFocusNode.unfocus();
    _scrollToBottom();

    final result = await _supportService.addFollowUpMessage(
      ticketId: widget.ticketId,
      email: widget.userEmail,
      message: message,
    );

    if (mounted) {
      setState(() {
        _isSending = false;
      });

      if (result.success) {
        // Record in recent activity
        await RecentActivityService.addTicketReplied(
          userId: widget.userEmail,
          ticketId: widget.ticketId,
          subject: _ticket!.subject,
          isUserReply: true,
        );
        // Reload to get the actual reply with correct ID
        _loadTicketDetails();
        _showSuccessSnackbar('Message sent');
      } else {
        // Rollback optimistic update on error
        setState(() {
          _ticket = SupportTicketDetail(
            id: _ticket!.id,
            subject: _ticket!.subject,
            message: _ticket!.message,
            status: _ticket!.status,
            type: _ticket!.type,
            priority: _ticket!.priority,
            createdAt: _ticket!.createdAt,
            updatedAt: _ticket!.updatedAt,
            replies: _ticket!.replies.where((r) => r.id != -1).toList(),
          );
        });
        _messageController.text = message; // Restore message
        _showErrorSnackbar(result.errorMessage ?? 'Failed to send message');
      }
    }
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.orange.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        action: SnackBarAction(
          label: 'Retry',
          textColor: Colors.white,
          onPressed: _sendFollowUp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Ticket #${widget.ticketId}',
              style: const TextStyle(
                color: Colors.black,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (_lastUpdate != null)
              Text(
                'Updated ${_formatRelativeTime(_lastUpdate!)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
              ),
          ],
        ),
        actions: [
          if (_ticket?.status == TicketStatus.resolved)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF10B981), size: 14),
                  SizedBox(width: 4),
                  Text(
                    'Resolved',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadTicketDetails,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF4A90A4)),
            )
          : _errorMessage != null
          ? _buildErrorState()
          : _buildContent(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTicketDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A90A4),
              ),
              child: const Text(
                'Try Again',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_ticket == null) return const SizedBox();

    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadTicketDetails,
            color: const Color(0xFF4A90A4),
            child: SingleChildScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Ticket header card
                  _buildTicketHeader(),
                  const SizedBox(height: 16),

                  // Conversation section header
                  _buildConversationHeader(),
                  const SizedBox(height: 12),

                  // Original message
                  _buildOriginalMessage(),
                  const SizedBox(height: 8),

                  // Conversation thread
                  ..._ticket!.replies.map(_buildReplyBubble),

                  // Empty state if no replies
                  if (_ticket!.replies.isEmpty) _buildEmptyRepliesState(),
                ],
              ),
            ),
          ),
        ),

        // Reply input (only show if ticket is not resolved)
        if (_ticket!.status != TicketStatus.resolved)
          _buildReplyInput()
        else
          _buildResolvedBanner(),
      ],
    );
  }

  Widget _buildTicketHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _ticket!.subject,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              _buildStatusBadge(_ticket!.status),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildInfoItem(Icons.category, _ticket!.type.displayName),
              const SizedBox(width: 16),
              _buildInfoItem(
                Icons.flag,
                _ticket!.priority.displayName,
                color: _ticket!.priority.color,
              ),
            ],
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Created: ${_formatDate(_ticket!.createdAt)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              Text(
                '${_ticket!.replies.length} ${_ticket!.replies.length == 1 ? 'reply' : 'replies'}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConversationHeader() {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF4A90A4),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Conversation',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        if (_hasNewMessages)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'New',
              style: TextStyle(
                color: Color(0xFF10B981),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOriginalMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF4A90A4).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF4A90A4).withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundColor: Color(0xFF4A90A4),
                child: Icon(Icons.person, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'You',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              ),
              const Spacer(),
              Text(
                _formatTime(_ticket!.createdAt),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _ticket!.message,
            style: const TextStyle(fontSize: 14, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyRepliesState() {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          Text(
            'No replies yet',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Our support team will respond shortly',
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyBubble(TicketReply reply) {
    final isUserReply = reply.isUserReply;
    final isPending = reply.id == -1; // Optimistic update

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUserReply
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUserReply) ...[
            const CircleAvatar(
              radius: 16,
              backgroundColor: Color(0xFF10B981),
              child: Icon(Icons.support_agent, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUserReply
                    ? (isPending
                          ? const Color(0xFF4A90A4).withValues(alpha: 0.7)
                          : const Color(0xFF4A90A4))
                    : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(12),
                  topRight: const Radius.circular(12),
                  bottomLeft: Radius.circular(isUserReply ? 12 : 4),
                  bottomRight: Radius.circular(isUserReply ? 4 : 12),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isUserReply && reply.adminName != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        reply.adminName!,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
                  Text(
                    reply.message,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: isUserReply ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isPending ? 'Sending...' : _formatTime(reply.createdAt),
                        style: TextStyle(
                          fontSize: 11,
                          color: isUserReply
                              ? Colors.white.withValues(alpha: 0.7)
                              : Colors.grey.shade500,
                        ),
                      ),
                      if (isPending) ...[
                        const SizedBox(width: 4),
                        SizedBox(
                          width: 10,
                          height: 10,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (isUserReply) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF4A90A4).withValues(alpha: 0.2),
              child: const Icon(
                Icons.person,
                color: Color(0xFF4A90A4),
                size: 18,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReplyInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).padding.bottom + 12,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              focusNode: _messageFocusNode,
              maxLines: 4,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'Type your message...',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: const BorderSide(
                    color: Color(0xFF4A90A4),
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendFollowUp(),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: _isSending ? Colors.grey : const Color(0xFF4A90A4),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSending ? null : _sendFollowUp,
              icon: _isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResolvedBanner() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF10B981).withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF10B981).withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.check_circle, color: Color(0xFF10B981), size: 20),
          const SizedBox(width: 8),
          const Text(
            'This ticket has been resolved',
            style: TextStyle(
              color: Color(0xFF10B981),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(TicketStatus status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 14, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: TextStyle(
              color: status.color,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color ?? Colors.grey.shade600, fontSize: 13),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return DateFormat('MMM d, yyyy').format(date);
  }

  String _formatTime(DateTime date) {
    return DateFormat('MMM d, h:mm a').format(date);
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return DateFormat('MMM d').format(date);
    }
  }
}
