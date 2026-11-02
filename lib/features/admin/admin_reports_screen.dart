import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../orders/data/order_service.dart';
import '../orders/models/order.dart';
import 'data/orders_csv.dart';
import 'models/report_period.dart';
import 'models/sales_report.dart';

/// Sales, products and factory reports with a CSV export.
class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key, required this.service, this.clock});

  final OrderService service;

  /// Source of the current time (tests can replace it).
  final DateTime Function()? clock;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  List<Order> _orders = const <Order>[];
  ReportPeriod _period = ReportPeriod.last30Days;
  late DateTime _now;
  bool _hasLoaded = false;
  bool _hasError = false;
  bool _isExporting = false;

  DateTime _clock() => (widget.clock ?? DateTime.now)();

  @override
  void initState() {
    super.initState();
    _now = _clock();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<Order> orders = await widget.service.listOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _now = _clock();
        _hasLoaded = true;
        _hasError = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  /// Saves the orders of the chosen period as a CSV file and shares it.
  Future<void> _exportCsv(SalesReport report) async {
    if (_isExporting || report.periodOrders.isEmpty) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() => _isExporting = true);
    try {
      final Directory directory = await getTemporaryDirectory();
      final File file = File(
        '${directory.path}/orders_${_period.name}_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(OrdersCsv.build(report.periodOrders), flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        <XFile>[XFile(file.path, mimeType: 'text/csv')],
        subject: 'Orders report - ${_period.label}',
      );
    } on Exception {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Could not create the file. Please try again.'),
          ),
        );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final SalesReport? report = _hasLoaded
        ? SalesReport.build(_orders, period: _period, now: _now)
        : null;
    final SalesReport? exportable =
        (report != null && report.periodOrders.isNotEmpty && !_isExporting)
            ? report
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Export orders (CSV)',
            onPressed:
                exportable == null ? null : () => _exportCsv(exportable),
            icon: const Icon(Icons.ios_share_rounded),
          ),
        ],
      ),
      body: _buildBody(report),
    );
  }

  Widget _buildBody(SalesReport? report) {
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
    if (report == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'No orders yet. Reports appear after the first order.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final TextTheme textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          _PeriodSelector(
            selected: _period,
            onSelected: (ReportPeriod period) {
              setState(() => _period = period);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (report.periodOrders.isEmpty)
            const _ReportCard(
              title: 'No orders in this period',
              child: Text('Choose a longer period to see more.'),
            )
          else ...<Widget>[
            _MetricGrid(report: report),
            const SizedBox(height: AppSpacing.sm),
            Text(
              report.hasUnpricedOrders
                  ? 'Values are estimates from starting prices. Items quoted after review are not included.'
                  : 'Values are estimates from starting prices. Final prices are confirmed per order.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            if (report.timeline.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              _ReportCard(
                title: 'Orders over time',
                child: _OrdersChart(buckets: report.timeline),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            _ReportCard(
              title: 'Orders by status',
              child: _StatusBreakdown(report: report),
            ),
            const SizedBox(height: AppSpacing.md),
            _ReportCard(
              title: 'Top products',
              child: _ProductsSection(products: report.products),
            ),
            const SizedBox(height: AppSpacing.md),
            _ReportCard(
              title: 'Factories',
              child: _FactoriesSection(report: report),
            ),
          ],
        ],
      ),
    );
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({required this.selected, required this.onSelected});

  final ReportPeriod selected;
  final ValueChanged<ReportPeriod> onSelected;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: <Widget>[
          for (final ReportPeriod period in ReportPeriod.values)
            Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: ChoiceChip(
                label: Text(period.label),
                selected: period == selected,
                selectedColor: AppColors.primaryLight,
                onSelected: (_) => onSelected(period),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final int cancelledPercent = (report.cancellationRate * 100).round();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.5,
      children: <Widget>[
        _MetricCard(
          label: 'Orders',
          value: '${report.activeOrders}',
          note: report.cancelledOrders > 0
              ? '${report.cancelledOrders} cancelled'
              : null,
        ),
        _MetricCard(label: 'Pieces', value: '${report.totalPieces}'),
        _MetricCard(
          label: 'Estimated value',
          value: Formatters.price(report.estimatedRevenue),
        ),
        _MetricCard(
          label: 'Average order',
          value: Formatters.price(report.averageOrderValue),
        ),
        _MetricCard(
          label: 'Delivered value',
          value: Formatters.price(report.deliveredRevenue),
          note: '${report.deliveredOrders} delivered',
        ),
        _MetricCard(
          label: 'Cancelled',
          value: '$cancelledPercent%',
          note: '${report.cancelledOrders} of ${report.periodOrders.length}',
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.label, required this.value, this.note});

  final String label;
  final String value;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? noteText = note;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (noteText != null)
              Text(
                noteText,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.md),
            child,
          ],
        ),
      ),
    );
  }
}

/// Simple bar chart drawn with widgets (no chart package needed).
class _OrdersChart extends StatelessWidget {
  const _OrdersChart({required this.buckets});

  final List<TimelineBucket> buckets;

  static const double _barAreaHeight = 120;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final TextStyle? labelStyle =
        textTheme.bodySmall?.copyWith(color: AppColors.textMuted);
    final int maxOrders = buckets.fold<int>(
      0,
      (int best, TimelineBucket bucket) => math.max(best, bucket.orders),
    );
    if (maxOrders == 0) {
      return Text('No orders in this period', style: labelStyle);
    }
    final double gap = buckets.length > 14 ? 1 : 3;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: _barAreaHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              for (final TimelineBucket bucket in buckets)
                Expanded(
                  child: Tooltip(
                    message: '${bucket.label}: ${bucket.orders} order(s)',
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: gap),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: bucket.orders == 0
                            ? const SizedBox(
                                width: double.infinity,
                                height: 2,
                                child: ColoredBox(color: AppColors.border),
                              )
                            : FractionallySizedBox(
                                widthFactor: 1,
                                heightFactor: bucket.orders / maxOrders,
                                child: const DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.vertical(
                                      top: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        _buildLabels(labelStyle),
        const SizedBox(height: AppSpacing.xs),
        Text('Highest: $maxOrders order(s)', style: labelStyle),
      ],
    );
  }

  Widget _buildLabels(TextStyle? style) {
    if (buckets.length <= 8) {
      return Row(
        children: <Widget>[
          for (final TimelineBucket bucket in buckets)
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(bucket.label, style: style),
              ),
            ),
        ],
      );
    }
    final TimelineBucket middle = buckets[buckets.length ~/ 2];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(buckets.first.label, style: style),
        Text(middle.label, style: style),
        Text(buckets.last.label, style: style),
      ],
    );
  }
}

/// A label and a value with a progress bar underneath.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.trailing,
    required this.fraction,
    this.color = AppColors.primary,
  });

  final String label;
  final String trailing;

  /// Bar fill, from 0 to 1.
  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                trailing,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xs),
          LinearProgressIndicator(
            value: fraction.clamp(0.0, 1.0).toDouble(),
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
            backgroundColor: AppColors.border,
            color: color,
          ),
        ],
      ),
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final int total = report.periodOrders.length;

    return Column(
      children: <Widget>[
        for (final OrderStatus status in OrderStatus.values)
          _BarRow(
            label: status.label,
            trailing: '${report.statusCounts[status] ?? 0}',
            fraction: total == 0 ? 0 : (report.statusCounts[status] ?? 0) / total,
            color: status == OrderStatus.cancelled
                ? AppColors.error
                : AppColors.primary,
          ),
      ],
    );
  }
}

class _ProductsSection extends StatelessWidget {
  const _ProductsSection({required this.products});

  final List<ProductSales> products;

  static const int _maxRows = 8;

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) {
      return const Text('No sales in this period');
    }
    final int maxPieces = products.first.pieces;
    final List<ProductSales> shown = products.take(_maxRows).toList();

    return Column(
      children: <Widget>[
        for (final ProductSales product in shown)
          _BarRow(
            label: product.category,
            trailing: _describe(product),
            fraction: maxPieces == 0 ? 0 : product.pieces / maxPieces,
          ),
      ],
    );
  }

  static String _describe(ProductSales product) {
    final String pieces = '${product.pieces} pcs';
    if (product.value <= 0) return pieces;
    return '$pieces · ${Formatters.price(product.value)}';
  }
}

class _FactoriesSection extends StatelessWidget {
  const _FactoriesSection({required this.report});

  final SalesReport report;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<FactoryLoad> factories = report.factories;
    final int maxOrders = factories.isEmpty ? 0 : factories.first.orders;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (report.waitingForFactory > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              '${report.waitingForFactory} order(s) waiting for a factory',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (factories.isEmpty)
          const Text('No orders assigned to a factory yet')
        else
          for (final FactoryLoad factory in factories)
            _BarRow(
              label: factory.name,
              trailing: '${factory.orders} order(s) · ${factory.pieces} pcs',
              fraction: maxOrders == 0 ? 0 : factory.orders / maxOrders,
            ),
      ],
    );
  }
}
