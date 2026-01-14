// Admin Dashboard Screen
import 'package:flutter/material.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              // Logout logic
            },
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 2,
        padding: const EdgeInsets.all(16),
        children: [
          _buildDashboardCard(
            context,
            'Manage Users',
            Icons.people,
            Colors.blue,
            () {
              // Navigate to user management
            },
          ),
          _buildDashboardCard(
            context,
            'Reports',
            Icons.bar_chart,
            Colors.green,
            () {
              // Navigate to reports
            },
          ),
          _buildDashboardCard(
            context,
            'Settings',
            Icons.settings,
            Colors.orange,
            () {
              // Navigate to settings
            },
          ),
          _buildDashboardCard(
            context,
            'Analytics',
            Icons.analytics,
            Colors.purple,
            () {
              // Navigate to analytics
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
