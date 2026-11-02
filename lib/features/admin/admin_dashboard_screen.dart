import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../notes/data/note_service.dart';
import '../notes/models/order_note.dart';
import '../orders/data/order_service.dart';
import '../orders/models/order.dart';
import 'admin_catalog_screen.dart';
import 'admin_factories_screen.dart';
import 'admin_issues_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_reports_screen.dart';
import 'models/order_stats.dart';

/// Admin home: order numbers at a glance and links to management tools.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key, this.service});

  final OrderService? service;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final OrderService _service = widget.service ?? OrderService();

  final NoteService _noteService = NoteService();
  OrderStats? _stats;
  int _openIssueCount = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<Order> orders = await _service.listOrders();
      final int issues = await _countOpenIssues(orders);
      if (!mounted) return;
      setState(() {
        _stats = OrderStats.from(orders);
        _openIssueCount = issues;
        _hasError = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  /// Open issues are extra information: if they cannot be read, the
  /// dashboard still shows the orders.
  Future<int> _countOpenIssues(List<Order> orders) async {
    try {
      final List<OrderNote> notes = await _noteService.listAll();
      return NoteService.openIssuesFor(orders, notes).length;
    } on Exception catch (error) {
      debugPrint('Could not read the notes: $error');
      return 0;
    }
  }

  Future<void> _openOrders() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminOrdersScreen(service: _service),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  void _openReports() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminReportsScreen(service: _service),
      ),
    );
  }

  void _openFactories() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminFactoriesScreen()),
    );
  }

  Future<void> _openIssues() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AdminIssuesScreen(
          service: _service,
          noteService: _noteService,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  void _openCatalog() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminCatalogScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Admin panel')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final OrderStats? stats = _stats;
    if (stats == null) {
      if (_hasError) {
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Text('Could not load the orders'),
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        );
      }
      return const Center(child: CircularProgressIndicator());
    }

    final TextTheme textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppSpacing.md,
            crossAxisSpacing: AppSpacing.md,
            childAspectRatio: 1.5,
            children: <Widget>[
              _StatCard(
                label: 'All orders',
                value: '${stats.total}',
                icon: Icons.receipt_long_rounded,
              ),
              _StatCard(
                label: 'New',
                value: '${stats.newOrders}',
                icon: Icons.fiber_new_rounded,
              ),
              _StatCard(
                label: 'In progress',
                value: '${stats.inProgress}',
                icon: Icons.precision_manufacturing_outlined,
              ),
              _StatCard(
                label: 'Delivered',
                value: '${stats.delivered}',
                icon: Icons.check_circle_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Estimated value (not cancelled)',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    Formatters.price(stats.activeValue),
                    style: textTheme.headlineSmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (stats.hasUnpricedOrders) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'Some orders are quoted after review and are not included.',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                  if (stats.cancelled > 0) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      '${stats.cancelled} cancelled order(s)',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Manage',
            style: textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _NavTile(
            icon: Icons.receipt_long_outlined,
            title: 'Orders',
            subtitle: 'View, search and update orders',
            onTap: _openOrders,
          ),
          _NavTile(
            icon: Icons.report_problem_outlined,
            title: 'Issues and delays',
            subtitle: _openIssueCount == 0
                ? 'No open issues'
                : '$_openIssueCount open issue(s) need attention',
            onTap: _openIssues,
          ),
          _NavTile(
            icon: Icons.sell_outlined,
            title: 'Products and prices',
            subtitle: 'Edit prices, styles and sizes',
            onTap: _openCatalog,
          ),
          _NavTile(
            icon: Icons.factory_outlined,
            title: 'Factories',
            subtitle: 'Manage factories and assign orders',
            onTap: _openFactories,
          ),
          _NavTile(
            icon: Icons.bar_chart_rounded,
            title: 'Reports',
            subtitle: 'Sales, products, factories and CSV export',
            onTap: _openReports,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Icon(icon, color: AppColors.primary),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  label,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onTap != null;

    return Card(
      child: ListTile(
        enabled: enabled,
        onTap: onTap,
        leading: Icon(
          icon,
          color: enabled ? AppColors.primary : AppColors.textMuted,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: enabled ? const Icon(Icons.chevron_right_rounded) : null,
      ),
    );
  }
}
