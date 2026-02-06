import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/ticket_label_selector.dart';
import '../support/ticket_list_screen.dart';
import '../support/create_ticket_screen.dart';

/// Screen for reporting issues and providing feedback
class ReportFeedbackScreen extends StatefulWidget {
  const ReportFeedbackScreen({super.key});

  @override
  State<ReportFeedbackScreen> createState() => _ReportFeedbackScreenState();
}

class _ReportFeedbackScreenState extends State<ReportFeedbackScreen> {
  final _authService = AuthService();
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = await _authService.getCachedUser();
    if (mounted) {
      setState(() {
        _user = user;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Report & Feedback',
          style: GoogleFonts.slackey(
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.darkBlue),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Card
                  _buildHeaderCard(),
                  const SizedBox(height: 24),

                  // Quick Actions Section
                  _buildSectionHeader('Quick Actions'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.bug_report,
                          title: 'Report Bug',
                          color: Colors.red.shade400,
                          onTap: () => _navigateToCreateTicket('bug'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.feedback,
                          title: 'Feedback',
                          color: Colors.blue.shade400,
                          onTap: () => _navigateToCreateTicket('feedback'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.help_outline,
                          title: 'General',
                          color: Colors.green.shade400,
                          onTap: () => _navigateToCreateTicket('general'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionCard(
                          icon: Icons.build,
                          title: 'Technical',
                          color: Colors.orange.shade400,
                          onTap: () => _navigateToCreateTicket('technical'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // My Tickets Section (only for logged in users)
                  if (_user != null) ...[
                    _buildSectionHeader('My Support Tickets'),
                    const SizedBox(height: 12),
                    _buildTicketsCard(),
                    const SizedBox(height: 24),
                  ],

                  // Help Topics
                  _buildSectionHeader('Common Topics'),
                  const SizedBox(height: 12),
                  _buildHelpTopicsCard(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.darkBlue,
            AppColors.darkBlue.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.darkBlue.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.support_agent, size: 48, color: Colors.white),
          const SizedBox(height: 12),
          const Text(
            'How can we help you?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'re here to help! Submit a ticket and our team will get back to you as soon as possible.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: AppColors.darkBlue,
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketsCard() {
    return InkWell(
      onTap: _navigateToTicketList,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.confirmation_number,
                color: AppColors.darkBlue,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'View My Tickets',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Track your support requests',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpTopicsCard() {
    final topics = [
      {
        'icon': Icons.route,
        'title': 'Route not working',
        'description': 'Having trouble finding routes?',
        'topicId': TicketLabelSelector.topicRouteNotWorking,
      },
      {
        'icon': Icons.attach_money,
        'title': 'Incorrect fare',
        'description': 'Report wrong fare calculations',
        'topicId': TicketLabelSelector.topicIncorrectFare,
      },
      {
        'icon': Icons.location_off,
        'title': 'Location issues',
        'description': 'GPS or location problems',
        'topicId': TicketLabelSelector.topicLocationIssues,
      },
      {
        'icon': Icons.speed,
        'title': 'App performance',
        'description': 'App running slow or crashing',
        'topicId': TicketLabelSelector.topicAppPerformance,
      },
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: List.generate(topics.length, (index) {
          final topic = topics[index];
          return Column(
            children: [
              InkWell(
                onTap: () => _navigateToCreateTicketWithTopic(
                  topic['topicId'] as String,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        topic['icon'] as IconData,
                        color: AppColors.darkBlue,
                        size: 22,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              topic['title'] as String,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              topic['description'] as String,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: Colors.grey.shade400,
                      ),
                    ],
                  ),
                ),
              ),
              if (index < topics.length - 1)
                const Divider(height: 1, indent: 54, endIndent: 16),
            ],
          );
        }),
      ),
    );
  }

  void _navigateToCreateTicket(String quickActionType) {
    if (_user == null) {
      _showLoginRequiredDialog();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTicketScreen(
          userEmail: _user!.email,
          userName: _user!.name,
          quickActionType: quickActionType,
        ),
      ),
    );
  }

  void _navigateToCreateTicketWithTopic(String topicId) {
    if (_user == null) {
      _showLoginRequiredDialog();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreateTicketScreen(
          userEmail: _user!.email,
          userName: _user!.name,
          commonTopicId: topicId,
        ),
      ),
    );
  }

  void _navigateToTicketList() {
    if (_user == null) {
      _showLoginRequiredDialog();
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            TicketListScreen(userEmail: _user!.email, userName: _user!.name),
      ),
    );
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.darkBlue),
            SizedBox(width: 8),
            Text('Login Required'),
          ],
        ),
        content: const Text(
          'Please log in to submit support tickets and track your requests.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
}
