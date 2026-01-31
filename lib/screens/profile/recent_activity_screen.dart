import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';

/// Screen to display user's recent activity
class RecentActivityScreen extends StatelessWidget {
  const RecentActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Sample activity data - in real app, this would come from a service
    final List<ActivityItem> activities = [
      ActivityItem(
        icon: Icons.route,
        title: 'Route Calculated',
        subtitle: 'SM City to Gaisano Mall',
        time: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      ActivityItem(
        icon: Icons.search,
        title: 'Location Search',
        subtitle: 'Searched for "Ayala Center"',
        time: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      ActivityItem(
        icon: Icons.calculate,
        title: 'Fare Calculated',
        subtitle: 'P25.00 - 12J route',
        time: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      ActivityItem(
        icon: Icons.route,
        title: 'Route Calculated',
        subtitle: 'Robinsons to Terminal',
        time: DateTime.now().subtract(const Duration(days: 1)),
      ),
      ActivityItem(
        icon: Icons.bookmark,
        title: 'Route Saved',
        subtitle: 'Home to Work route',
        time: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

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
      ),
      body: activities.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: activities.length,
              itemBuilder: (context, index) {
                final activity = activities[index];
                final showDateHeader =
                    index == 0 ||
                    !_isSameDay(activities[index - 1].time, activity.time);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showDateHeader) ...[
                      if (index != 0) const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          _formatDateHeader(activity.time),
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

  Widget _buildActivityCard(ActivityItem activity) {
    return Card(
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
              child: Icon(activity.icon, color: AppColors.darkBlue, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activity.title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activity.subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            Text(
              _formatTime(activity.time),
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    if (_isSameDay(date, now)) {
      return 'Today';
    } else if (_isSameDay(date, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    } else {
      return '${_monthName(date.month)} ${date.day}, ${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour > 12 ? date.hour - 12 : date.hour;
    final period = date.hour >= 12 ? 'PM' : 'AM';
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}

class ActivityItem {
  final IconData icon;
  final String title;
  final String subtitle;
  final DateTime time;

  ActivityItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.time,
  });
}
