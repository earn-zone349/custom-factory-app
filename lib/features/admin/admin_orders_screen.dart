import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/date_formatters.dart';
import '../orders/data/order_service.dart';
import '../orders/models/order.dart';
import '../orders/models/order_display.dart';
import '../orders/widgets/order_status_chip.dart';
import 'admin_order_detail_screen.dart';

/// All orders with status filters and search.
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key, required this.service});

  final OrderService service;

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  List<Order> _orders = const <Order>[];
  OrderStatus? _filter;
  String _query = '';
  bool _hasLoaded = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final List<Order> orders = await widget.service.listOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
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
        builder: (_) => AdminOrderDetailScreen(
          order: order,
          service: widget.service,
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  List<Order> get _visibleOrders {
    final String query = _query.trim().toLowerCase();
    return _orders.where((Order order) {
      if (_filter != null && order.status != _filter) return false;
      if (query.isEmpty) return true;
      return order.id.toLowerCase().contains(query) ||
          order.address.fullName.toLowerCase().contains(query) ||
          order.address.phone.contains(query);
    }).toList();
  }

  int _countFor(OrderStatus? status) {
    if (status == null) return _orders.length;
    return _orders.where((Order order) => order.status == status).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orders')),
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

    final List<Order> visible = _visibleOrders;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            0,
          ),
          child: TextField(
            onChanged: (String value) => setState(() => _query = value),
            decoration: const InputDecoration(
              hintText: 'Search order number, name or phone',
              prefixIcon: Icon(Icons.search_rounded),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: <Widget>[
              for (final OrderStatus? status in <OrderStatus?>[
                null,
                ...OrderStatus.values,
              ])
                Padding(
                  padding: const EdgeInsets.only(right: AppSpacing.sm),
                  child: ChoiceChip(
                    label: Text(
                      '${status?.label ?? 'All'} (${_countFor(status)})',
                    ),
                    selected: _filter == status,
                    selectedColor: AppColors.primaryLight,
                    onSelected: (_) => setState(() => _filter = status),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: visible.isEmpty
              ? const Center(child: Text('No orders found'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: visible.length,
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (BuildContext context, int index) {
                      final Order order = visible[index];
                      return _AdminOrderCard(
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

class _AdminOrderCard extends StatelessWidget {
  const _AdminOrderCard({required this.order, required this.onTap});

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
                '${order.address.fullName} · ${order.address.district}',
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                order.itemsSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              if (order.manufacturerName != null) ...<Widget>[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'Factory: ${order.manufacturerName}',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Text(
                    '${order.totalPieces} pieces',
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    order.totalText,
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
