import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/recent_activity_model.dart';
import '../../services/recent_activity_service_v2.dart';
import '../../services/auth_service.dart';

/// Screen to display user's recent activity
class RecentActivityScreen extends StatefulWidget {
  const RecentActivityScreen({super.key});

  @override
  State<RecentActivityScreen> createState() => _RecentActivityScreenState();
}

class _RecentActivityScreenState extends State<RecentActivityScreen> {
  final _authService = AuthService();
  List<RecentActivityModel> _activities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    setState(() => _isLoading = true);

    // Check if user is authenticated
    final isLoggedIn = await _authService.isLoggedIn();

    if (!isLoggedIn) {
      // Clear activities if user is not logged in (guest mode)
      await RecentActivityServiceV2.clearAll();
      setState(() {
        _activities = [];
        _isLoading = false;
      });
      return;
    }

    // Load activities from local database
    final activities = await RecentActivityServiceV2.getActivities();

    setState(() {
      _activities = activities;
      _isLoading = false;
    });
  }

  Future<void> _deleteActivity(RecentActivityModel activity) async {
    if (activity.id != null) {
      await RecentActivityServiceV2.deleteActivity(
        activity.id!,
        serverId: activity.serverId,
      );
      _loadActivities();
    }
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Activities'),
        content: const Text(
          'Are you sure you want to clear all recent activities?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await RecentActivityServiceV2.clearAll();
      _loadActivities();
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
          'Recent Activity',
          style: GoogleFonts.slackey(
            fontSize: 20,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          if (_activities.isNotEmpty)
            IconButton(
              icon: const Icon(
                Icons.delete_sweep,
                color: AppColors.textPrimary,
              ),
              onPressed: _clearAll,
              tooltip: 'Clear all',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activities.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadActivities,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _activities.length,
                itemBuilder: (context, index) {
                  final activity = _activities[index];
                  final showDateHeader =
                      index == 0 ||
                      _activities[index - 1].dateHeader != activity.dateHeader;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showDateHeader) ...[
                        if (index != 0) const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            activity.dateHeader,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                      ],
                      _buildActivityCard(activity),
                    ],
                  );
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.history, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'No recent activity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recent actions will appear here',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(RecentActivityModel activity) {
    return Dismissible(
      key: Key(activity.id?.toString() ?? DateTime.now().toString()),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteActivity(activity),
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _getActivityIcon(activity.activityType),
                  color: AppColors.darkBlue,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getActivityTitle(activity),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!activity.isSynced)
                          Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.cloud_off,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    _buildSubtitle(activity),
                  ],
                ),
              ),
              Text(
                activity.formattedTime,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubtitle(RecentActivityModel activity) {
    final subtitle = activity.subtitle ?? '';

    // For fare_calculated, highlight the fare amounts
    if (activity.activityType == 'fare_calculated' && subtitle.contains('₱')) {
      // Parse the subtitle to find fare amounts
      final parts = subtitle.split('|');
      if (parts.length >= 2) {
        // parts[0] = location info, parts[1] = fare info
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              parts[0].trim(),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: parts[1].trim(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkBlue,
                    ),
                  ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        );
      }
    }

    // Default subtitle display
    return Text(
      subtitle,
      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }

  String _getActivityTitle(RecentActivityModel activity) {
    switch (activity.activityType) {
      case 'route_calculated':
        return 'Route Calculated';
      case 'fare_calculated':
        return 'Fare Calculated';
      case 'location_search':
        return 'Location Searched';
      case 'route_saved':
        return 'Route Saved';
      case 'support_ticket':
      case 'customer_service':
        return 'Support Ticket';
      default:
        return activity.title;
    }
  }

  IconData _getActivityIcon(String activityType) {
    switch (activityType) {
      case 'route_calculated':
        return Icons.route;
      case 'fare_calculated':
        return Icons.calculate;
      case 'location_search':
        return Icons.search;
      case 'route_saved':
        return Icons.bookmark;
      case 'support_ticket':
      case 'customer_service':
        return Icons.confirmation_number;
      default:
        return Icons.history;
    }
  }
}
