import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/date_formatters.dart';
import '../manufacturers/models/manufacturer.dart';
import '../orders/data/order_service.dart';
import '../orders/models/order.dart';
import '../orders/models/order_display.dart';
import '../orders/widgets/order_status_chip.dart';
import 'factory_order_detail_screen.dart';
import 'models/factory_order_filter.dart';

/// The orders given to one factory, with filters.
class FactoryOrdersScreen extends StatefulWidget {
  const FactoryOrdersScreen({
    super.key,
    required this.factory,
    required this.service,
    required this.onSwitchFactory,
  });

  final Manufacturer factory;
  final OrderService service;
  final VoidCallback onSwitchFactory;

  @override
  State<FactoryOrdersScreen> createState() => _FactoryOrdersScreenState();
}

class _FactoryOrdersScreenState extends State<FactoryOrdersScreen> {
  List<Order> _orders = const <Order>[];
  FactoryOrderFilter _filter = FactoryOrderFilter.allActive;
  bool _hasLoaded = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FactoryOrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.factory.id != widget.factory.id) _load();
  }

  Future<void> _load() async {
    final String factoryId = widget.factory.id;
    try {
      final List<Order> all = await widget.service.listOrders();
      if (!mounted) return;
      setState(() {
        _orders = all
            .where(
              (Order order) => OrderService.isVisibleToFactory(order, factoryId),
            )
            .toList();
        _hasLoaded = true;
        _hasError = false;
      });
    } on Exception {
      if (!mounted) return;
      setState(() => _hasError = true);
    }
  }

  Future<void> _openOrder(Order order) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FactoryOrderDetailScreen(
          order: order,
          factoryId: widget.factory.id,
          service: widget.service,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  int _countFor(FactoryOrderFilter filter) {
    return _orders.where(filter.matches).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.factory.name),
        actions: <Widget>[
          IconButton(
            tooltip: 'Switch factory',
            onPressed: widget.onSwitchFactory,
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
    if (!_hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'No orders for your factory yet. Orders appear here after the admin confirms them and assigns your factory.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    final List<Order> visible =
        _orders.where(_filter.matches).toList();

    return Column(
      children: <Widget>[
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              for (final FactoryOrderFilter filter in FactoryOrderFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text('${filter.label} (${_countFor(filter)})'),
                    selected: filter == _filter,
                    selectedColor: AppColors.primaryLight,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('No orders here'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: visible.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (BuildContext context, int index) {
                      final Order order = visible[index];
                      return _FactoryOrderCard(
                        order: order,
                        onTap: () => _openOrder(order),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _FactoryOrderCard extends StatelessWidget {
  const _FactoryOrderCard({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      order.id,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  OrderStatusChip(status: order.status),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                DateFormatters.dateTime(order.createdAt),
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                order.itemsSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '${order.totalPieces} pieces',
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
