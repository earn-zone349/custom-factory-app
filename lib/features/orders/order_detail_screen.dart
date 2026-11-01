import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/utils/formatters.dart';
import '../cart/models/cart_item.dart';
import 'data/order_service.dart';
import 'models/order.dart';
import 'models/order_display.dart';
import 'widgets/order_status_chip.dart';
import 'widgets/order_status_timeline.dart';
import 'widgets/saved_design_thumbnail.dart';

/// Full details of one order: status tracking, items, address and payment.
class OrderDetailScreen extends StatefulWidget {
  const OrderDetailScreen({
    super.key,
    required this.order,
    required this.service,
  });

  final Order order;
  final OrderService service;

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late Order _order = widget.order;
  bool _isCancelling = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copyOrderNumber() async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    String message = 'Order number copied';
    try {
      await Clipboard.setData(ClipboardData(text: _order.id));
    } on Exception {
      message = 'Could not copy the order number';
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancel() async {
    if (_isCancelling) return;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cancel this order?'),
          content: const Text('This cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Keep order'),
            ),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Cancel order'),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isCancelling = true);
    try {
      await widget.service.cancelOrder(_order.id);
      final Order? updated = await widget.service.findOrder(_order.id);
      if (!mounted) return;
      if (updated != null) setState(() => _order = updated);
      _showMessage('Order cancelled');
    } on StateError {
      if (!mounted) return;
      _showMessage('This order can no longer be cancelled.');
    } on Exception {
      if (!mounted) return;
      _showMessage('Could not cancel the order. Please try again.');
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Order order = _order;

    return Scaffold(
      appBar: AppBar(title: const Text('Order details')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          order.id,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        Text(
                          DateFormatters.dateTime(order.createdAt),
                          style: textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        OrderStatusChip(status: order.status),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy order number',
                    onPressed: _copyOrderNumber,
                    icon: const Icon(Icons.copy_rounded),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Order status',
            child: OrderStatusTimeline(status: order.status),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Items',
            child: Column(
              children: <Widget>[
                for (final CartItem item in order.items) _ItemRow(item: item),
                const Divider(),
                _InfoRow(label: 'Total pieces', value: '${order.totalPieces}'),
                _InfoRow(label: 'Estimated total', value: order.totalText),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Delivery',
            child: Column(
              children: <Widget>[
                _InfoRow(label: 'Name', value: order.address.fullName),
                _InfoRow(label: 'Phone', value: order.address.phone),
                _InfoRow(label: 'Address', value: order.address.formatted),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          _SectionCard(
            title: 'Payment',
            child: _InfoRow(
              label: 'Method',
              value: order.paymentMethod.label,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Final price and delivery charge are confirmed by our team before production.',
            style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          if (OrderService.canCancel(order)) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.error,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _isCancelling ? null : _cancel,
              child: _isCancelling
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Cancel order'),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

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

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 64,
            child: SavedDesignThumbnail(designId: item.designId),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${item.category} x ${item.quantity}',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  item.summary,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                if (item.notes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text(item.notes, style: textTheme.bodySmall),
                ],
                const SizedBox(height: AppSpacing.xs),
                Text(
                  item.hasEstimate
                      ? Formatters.price(item.lineTotal)
                      : 'Quote after review',
                  style: textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
