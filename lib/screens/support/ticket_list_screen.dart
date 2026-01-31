import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/support_ticket.dart';
import '../../services/support_service.dart';
import 'create_ticket_screen.dart';
import 'ticket_detail_screen.dart';

/// Screen to display list of user's support tickets
class TicketListScreen extends StatefulWidget {
  final String userEmail;
  final String userName;

  const TicketListScreen({
    super.key,
    required this.userEmail,
    required this.userName,
  });

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  final SupportService _supportService = SupportService();
  final ScrollController _scrollController = ScrollController();

  List<SupportTicket> _tickets = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  TicketStatus? _selectedStatus;

  int _currentPage = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _loadTickets();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreTickets();
    }
  }

  Future<void> _loadTickets() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _currentPage = 1;
    });

    final result = await _supportService.getTickets(
      email: widget.userEmail,
      status: _selectedStatus,
      page: 1,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.success) {
          _tickets = result.tickets;
          _currentPage = result.currentPage;
          _lastPage = result.lastPage;
        } else {
          _errorMessage = result.errorMessage;
        }
      });
    }
  }

  Future<void> _loadMoreTickets() async {
    if (_isLoadingMore || _currentPage >= _lastPage) return;

    setState(() {
      _isLoadingMore = true;
    });

    final result = await _supportService.getTickets(
      email: widget.userEmail,
      status: _selectedStatus,
      page: _currentPage + 1,
    );

    if (mounted) {
      setState(() {
        _isLoadingMore = false;
        if (result.success) {
          _tickets.addAll(result.tickets);
          _currentPage = result.currentPage;
          _lastPage = result.lastPage;
        }
      });
    }
  }

  void _navigateToCreateTicket() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTicketScreen(
          userEmail: widget.userEmail,
          userName: widget.userName,
        ),
      ),
    );

    if (result == true) {
      _loadTickets();
    }
  }

  void _navigateToTicketDetail(SupportTicket ticket) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TicketDetailScreen(
          ticketId: ticket.id,
          userEmail: widget.userEmail,
        ),
      ),
    );
    // Refresh list on return
    _loadTickets();
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
        title: const Text(
          'Support Tickets',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black),
            onPressed: _loadTickets,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilterChips(),
          Expanded(child: _buildBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToCreateTicket,
        backgroundColor: const Color(0xFF4A90A4),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('New Ticket', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(null, 'All'),
            const SizedBox(width: 8),
            _buildFilterChip(TicketStatus.pending, 'Pending'),
            const SizedBox(width: 8),
            _buildFilterChip(TicketStatus.inProgress, 'In Progress'),
            const SizedBox(width: 8),
            _buildFilterChip(TicketStatus.resolved, 'Resolved'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(TicketStatus? status, String label) {
    final isSelected = _selectedStatus == status;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black87,
        fontSize: 13,
      ),
      backgroundColor: Colors.grey.shade100,
      selectedColor: const Color(0xFF4A90A4),
      checkmarkColor: Colors.white,
      onSelected: (selected) {
        setState(() {
          _selectedStatus = selected ? status : null;
        });
        _loadTickets();
      },
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF4A90A4)),
      );
    }

    if (_errorMessage != null) {
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
                onPressed: _loadTickets,
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

    if (_tickets.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.support_agent, size: 80, color: Colors.grey.shade300),
              const SizedBox(height: 16),
              Text(
                'No support tickets yet',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Create a new ticket to get help from our support team',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _navigateToCreateTicket,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4A90A4),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.add, color: Colors.white),
                label: const Text(
                  'Create Ticket',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadTickets,
      color: const Color(0xFF4A90A4),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: _tickets.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == _tickets.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF4A90A4)),
              ),
            );
          }
          return _buildTicketCard(_tickets[index]);
        },
      ),
    );
  }

  Widget _buildTicketCard(SupportTicket ticket) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToTicketDetail(ticket),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      ticket.subject,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 12),
                  _buildStatusBadge(ticket.status),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildInfoChip(
                    Icons.category_outlined,
                    ticket.type.displayName,
                  ),
                  const SizedBox(width: 12),
                  _buildInfoChip(
                    Icons.flag_outlined,
                    ticket.priority.displayName,
                    color: ticket.priority.color,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Ticket #${ticket.id}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                  Text(
                    _formatDate(ticket.createdAt),
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
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

  Widget _buildInfoChip(IconData icon, String label, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color ?? Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(color: color ?? Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        return '${difference.inMinutes} min ago';
      }
      return '${difference.inHours} hours ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('MMM d, yyyy').format(date);
    }
  }
}
