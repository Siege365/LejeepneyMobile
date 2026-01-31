import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/support_ticket.dart';
import '../../services/support_service.dart';

/// Screen to display ticket details and conversation thread
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

class _TicketDetailScreenState extends State<TicketDetailScreen> {
  final SupportService _supportService = SupportService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  SupportTicketDetail? _ticket;
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadTicketDetails();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
        } else {
          _errorMessage = result.errorMessage;
        }
      });

      // Scroll to bottom after loading
      if (_ticket != null && _ticket!.replies.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }
  }

  Future<void> _sendFollowUp() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || message.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Message must be at least 10 characters'),
          backgroundColor: Colors.orange.shade600,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

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
        _messageController.clear();
        _loadTicketDetails();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Message sent successfully'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(result.errorMessage ?? 'Failed to send message'),
                ),
              ],
            ),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
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
        title: Text(
          'Ticket #${widget.ticketId}',
          style: const TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
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
          child: SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Ticket header card
                _buildTicketHeader(),
                const SizedBox(height: 16),

                // Original message
                _buildOriginalMessage(),
                const SizedBox(height: 16),

                // Conversation thread
                if (_ticket!.replies.isNotEmpty) ...[
                  _buildSectionHeader('Conversation'),
                  const SizedBox(height: 12),
                  ..._ticket!.replies.map(_buildReplyBubble),
                ],
              ],
            ),
          ),
        ),

        // Reply input (only show if ticket is not resolved)
        if (_ticket!.status != TicketStatus.resolved) _buildReplyInput(),
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
              if (_ticket!.updatedAt != null)
                Text(
                  'Updated: ${_formatDate(_ticket!.updatedAt!)}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
            ],
          ),
        ],
      ),
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
              CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF4A90A4),
                child: const Icon(Icons.person, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 8),
              const Text(
                'Your Message',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
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

  Widget _buildSectionHeader(String title) {
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
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildReplyBubble(TicketReply reply) {
    final isUserReply = reply.isUserReply;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUserReply
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUserReply) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: const Color(0xFF10B981),
              child: const Icon(
                Icons.support_agent,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isUserReply ? const Color(0xFF4A90A4) : Colors.white,
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
                  Text(
                    _formatTime(reply.createdAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isUserReply
                          ? Colors.white.withValues(alpha: 0.7)
                          : Colors.grey.shade500,
                    ),
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
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              maxLines: 3,
              minLines: 1,
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
            ),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF4A90A4),
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
}
