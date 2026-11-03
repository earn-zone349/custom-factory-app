import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../admin/models/report_period.dart';
import '../manufacturers/models/manufacturer.dart';
import '../notes/data/note_service.dart';
import '../notes/models/order_note.dart';
import '../orders/data/order_service.dart';
import '../orders/models/order.dart';
import 'data/factory_orders_csv.dart';
import 'models/factory_report.dart';
import 'widgets/report_widgets.dart';

/// A factory's own report: its orders, pieces, products and delays.
/// It shows no customer details and no prices.
class FactoryReportsScreen extends StatefulWidget {
  const FactoryReportsScreen({
    super.key,
    required this.factory,
    required this.service,
    this.noteService,
    this.clock,
  });

  final Manufacturer factory;
  final OrderService service;
  final NoteService? noteService;

  /// Source of the current time (tests can replace it).
  final DateTime Function()? clock;

  @override
  State<FactoryReportsScreen> createState() => _FactoryReportsScreenState();
}

class _FactoryReportsScreenState extends State<FactoryReportsScreen> {
  static const int _maxProductRows = 8;

  late final NoteService _noteService = widget.noteService ?? NoteService();

  List<Order> _orders = const <Order>[];
  List<OrderNote> _notes = const <OrderNote>[];
  ReportPeriod _period = ReportPeriod.last30Days;
  late DateTime _now;
  bool _hasLoaded = false;
  bool _hasError = false;
  bool _notesUnavailable = false;
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
      List<OrderNote> notes = const <OrderNote>[];
      bool notesUnavailable = false;
      try {
        notes = await _noteService.listAll();
      } on Exception catch (error) {
        debugPrint('Could not read the notes: $error');
        notesUnavailable = true;
      }
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _notes = notes;
        _notesUnavailable = notesUnavailable;
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
  Future<void> _exportCsv(FactoryReport report) async {
    if (_isExporting || report.orders.isEmpty) return;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() => _isExporting = true);
    try {
      final Directory directory = await getTemporaryDirectory();
      final String safeId =
          widget.factory.id.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-');
      final File file = File(
        '${directory.path}/orders_${safeId}_${_period.name}_${DateTime.now().millisecondsSinceEpoch}.csv',
      );
      await file.writeAsString(FactoryOrdersCsv.build(report.orders), flush: true);
      if (!mounted) return;
      await Share.shareXFiles(
        <XFile>[XFile(file.path, mimeType: 'text/csv')],
        subject: 'Factory orders - ${_period.label}',
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

  static String _daysText(double days) {
    final bool whole = days == days.roundToDouble();
    final String number =
        whole ? days.round().toString() : days.toStringAsFixed(1);
    return '$number day${days == 1 ? '' : 's'}';
  }

  @override
  Widget build(BuildContext context) {
    final FactoryReport? report = _hasLoaded
        ? FactoryReport.build(
            orders: _orders,
            notes: _notes,
            factoryId: widget.factory.id,
            period: _period,
            now: _now,
          )
        : null;
    final FactoryReport? exportable =
        (report != null && report.orders.isNotEmpty && !_isExporting)
            ? report
            : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Factory report'),
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

  Widget _buildBody(FactoryReport? report) {
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

    final String factoryId = widget.factory.id;
    final bool hasAnyOrder = _orders.any(
      (Order order) => OrderService.isVisibleToFactory(order, factoryId),
    );
    if (!hasAnyOrder) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'No orders for your factory yet. The report appears after the admin confirms an order and assigns it to you.',
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
          Text(
            widget.factory.name,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: AppSpacing.sm),
          _PeriodSelector(
            selected: _period,
            onSelected: (ReportPeriod period) {
              setState(() => _period = period);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          if (report.orders.isEmpty)
            const ReportCard(
              title: 'No orders in this period',
              child: Text('Choose a longer period to see more.'),
            )
          else ...<Widget>[
            _buildMetrics(report),
            if (report.timeline.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.md),
              ReportCard(
                title: 'Orders over time',
                child: OrdersBarChart(buckets: report.timeline),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            ReportCard(
              title: 'Orders by status',
              child: _buildStatuses(report),
            ),
            const SizedBox(height: AppSpacing.md),
            ReportCard(title: 'Products', child: _buildProducts(report)),
            const SizedBox(height: AppSpacing.md),
            ReportCard(
              title: 'Delays and problems',
              child: _buildDelays(report),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The period uses the date an order was placed. Production time is not measured yet.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetrics(FactoryReport report) {
    final int completedPercent = (report.completionRate * 100).round();

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppSpacing.md,
      crossAxisSpacing: AppSpacing.md,
      childAspectRatio: 1.5,
      children: <Widget>[
        ReportMetricCard(
          label: 'Orders',
          value: '${report.activeOrders}',
          note: report.cancelledOrders > 0
              ? '${report.cancelledOrders} cancelled'
              : null,
        ),
        ReportMetricCard(label: 'Pieces', value: '${report.totalPieces}'),
        ReportMetricCard(
          label: 'Pieces to make',
          value: '${report.piecesToMake}',
        ),
        ReportMetricCard(
          label: 'Pieces finished',
          value: '${report.piecesFinished}',
        ),
        ReportMetricCard(
          label: 'Completed',
          value: '$completedPercent%',
          note: '${report.finishedOrders} of ${report.activeOrders} orders',
        ),
        ReportMetricCard(
          label: 'Delayed orders',
          value: _notesUnavailable ? '-' : '${report.delayedOrders}',
          note: _notesUnavailable
              ? 'Notes unavailable'
              : (report.openDelays > 0 ? '${report.openDelays} open' : null),
        ),
      ],
    );
  }

  Widget _buildStatuses(FactoryReport report) {
    final int total = report.orders.length;

    return Column(
      children: <Widget>[
        for (final OrderStatus status in OrderStatus.values)
          if (status != OrderStatus.placed)
            ReportBarRow(
              label: status.label,
              trailing: '${report.statusCounts[status] ?? 0}',
              fraction:
                  total == 0 ? 0 : (report.statusCounts[status] ?? 0) / total,
              color: status == OrderStatus.cancelled
                  ? AppColors.error
                  : AppColors.primary,
            ),
      ],
    );
  }

  Widget _buildProducts(FactoryReport report) {
    if (report.products.isEmpty) {
      return const Text('No products in this period');
    }
    final int maxPieces = report.products.first.pieces;

    return Column(
      children: <Widget>[
        for (final FactoryProductLoad product
            in report.products.take(_maxProductRows))
          ReportBarRow(
            label: product.category,
            trailing: '${product.pieces} pcs · ${product.orders} order(s)',
            fraction: maxPieces == 0 ? 0 : product.pieces / maxPieces,
          ),
      ],
    );
  }

  Widget _buildDelays(FactoryReport report) {
    if (_notesUnavailable) {
      return const Text('Notes could not be read, so delays are not shown.');
    }
    if (report.delayReports == 0 && report.problemReports == 0) {
      return const Text('No delays or problems reported in this period.');
    }
    final int delayedPercent = (report.delayedOrderRate * 100).round();

    return Column(
      children: <Widget>[
        ReportInfoRow(
          label: 'Delay reports',
          value: '${report.delayReports}',
        ),
        if (report.delayReports > 0) ...<Widget>[
          ReportInfoRow(
            label: 'Average delay',
            value: _daysText(report.averageDelayDays),
          ),
          ReportInfoRow(
            label: 'Longest delay',
            value: _daysText(report.longestDelayDays.toDouble()),
          ),
        ],
        ReportInfoRow(
          label: 'Delayed orders',
          value:
              '${report.delayedOrders} of ${report.activeOrders} ($delayedPercent%)',
        ),
        ReportInfoRow(
          label: 'Problem reports',
          value: '${report.problemReports}',
        ),
        ReportInfoRow(label: 'Open issues', value: '${report.openIssues}'),
      ],
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
