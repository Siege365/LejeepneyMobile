// Routes List Panel Widget
// Extracted from SearchScreen - displays toggleable list of all routes
// Follows Single Responsibility Principle

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../constants/app_colors.dart';
import '../../models/jeepney_route.dart';
import '../route_list_item.dart';

/// Panel widget for displaying and toggling routes on map
class RoutesListPanel extends StatelessWidget {
  final List<JeepneyRoute> routes;
  final Set<int> visibleRouteIds;
  final bool isLoading;
  final String? errorMessage;
  final VoidCallback? onRetry;
  final void Function(JeepneyRoute route, bool isNowVisible) onRouteToggled;

  const RoutesListPanel({
    super.key,
    required this.routes,
    required this.visibleRouteIds,
    required this.isLoading,
    this.errorMessage,
    this.onRetry,
    required this.onRouteToggled,
  });

  /// Get sorted routes: visible first (alphabetically), then hidden (alphabetically)
  List<JeepneyRoute> get _sortedRoutes {
    final visibleRoutes = routes
        .where((r) => visibleRouteIds.contains(r.id))
        .toList();
    final hiddenRoutes = routes
        .where((r) => !visibleRouteIds.contains(r.id))
        .toList();

    visibleRoutes.sort((a, b) => a.name.compareTo(b.name));
    hiddenRoutes.sort((a, b) => a.name.compareTo(b.name));

    return [...visibleRoutes, ...hiddenRoutes];
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      constraints: const BoxConstraints(maxHeight: 300),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildHeader(),
          const SizedBox(height: 16),
          Flexible(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'List of Routes',
          style: GoogleFonts.slackey(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        if (isLoading)
          const Padding(
            padding: EdgeInsets.only(left: 12),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null) {
      return _ErrorState(message: errorMessage!, onRetry: onRetry);
    }

    if (routes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No routes available',
          style: TextStyle(color: AppColors.gray),
        ),
      );
    }

    return _RoutesList(
      routes: _sortedRoutes,
      visibleRouteIds: visibleRouteIds,
      onRouteToggled: onRouteToggled,
    );
  }
}

/// Error state widget
class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _ErrorState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.wifi_off, color: AppColors.warning, size: 32),
          const SizedBox(height: 8),
          Text(message, style: TextStyle(color: AppColors.warning)),
          const SizedBox(height: 8),
          if (onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
        ],
      ),
    );
  }
}

/// List of routes
class _RoutesList extends StatelessWidget {
  final List<JeepneyRoute> routes;
  final Set<int> visibleRouteIds;
  final void Function(JeepneyRoute route, bool isNowVisible) onRouteToggled;

  const _RoutesList({
    required this.routes,
    required this.visibleRouteIds,
    required this.onRouteToggled,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      itemCount: routes.length,
      itemBuilder: (context, index) {
        final route = routes[index];
        final isVisible = visibleRouteIds.contains(route.id);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: RouteListItem(
            routeName: route.displayName,
            isAvailable: route.isAvailable,
            isRouteVisible: isVisible,
            onTap: () => onRouteToggled(route, !isVisible),
          ),
        );
      },
    );
  }
}
