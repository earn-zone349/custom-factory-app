import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/date_formatters.dart';
import '../cart/models/cart_item.dart';
import '../orders/data/order_service.dart';
import '../orders/models/order.dart';
import '../orders/widgets/order_status_chip.dart';
import '../orders/widgets/order_status_timeline.dart';
import '../orders/widgets/saved_design_thumbnail.dart';
import '../notes/models/order_note.dart';
import '../notes/widgets/order_notes_card.dart';
import '../production/widgets/production_files_card.dart';

/// What a factory needs to produce one order. Customer details and prices
/// are not shown here: the admin team handles delivery and payment.
class FactoryOrderDetailScreen extends StatefulWidget {
  const FactoryOrderDetailScreen({
    super.key,
    required this.order,
    required this.factoryId,
    required this.service,
  });

  final Order order;
  final String factoryId;
  final OrderService service;

  @override
  State<FactoryOrderDetailScreen> createState() =>
      _FactoryOrderDetailScreenState();
}

class _FactoryOrderDetailScreenState extends State<FactoryOrderDetailScreen> {
  late Order _order = widget.order;
  bool _isUpdating = false;

  static String _actionLabel(OrderStatus next) {
    return switch (next) {
      OrderStatus.inProduction => 'Accept and start production',
      OrderStatus.qualityCheck => 'Mark production finished',
      _ => 'Update status',
    };
  }

  /// A short explanation when the factory has nothing to do right now.
  static String? _hint(OrderStatus status) {
    return switch (status) {
      OrderStatus.placed ||
      OrderStatus.confirmed ||
      OrderStatus.inProduction =>
        null,
      OrderStatus.qualityCheck =>
        'Production finished. Our team is checking the quality.',
      OrderStatus.outForDelivery =>
        'Quality approved. The order is on its way to the customer.',
      OrderStatus.delivered => 'This order has been delivered.',
      OrderStatus.cancelled => 'This order was cancelled. Please stop work on it.',
    };
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _advance(OrderStatus next) async {
    if (_isUpdating) return;
    setState(() => _isUpdating = true);
    try {
      final Order updated = await widget.service.changeStatusAsFactory(
        _order.id,
        widget.factoryId,
        next,
      );
      if (!mounted) return;
      setState(() => _order = updated);
      _showMessage('Status changed to ${next.label}');
    } on StateError catch (error) {
      if (!mounted) return;
      _showMessage(error.message);
    } on Exception {
      if (!mounted) return;
      _showMessage('Could not update the order. Please try again.');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Order order = _order;
    final OrderStatus? next = OrderService.factoryNextStatus(order);
    final String? hint = _hint(order.status);

    return Scaffold(
      appBar: AppBar(title: const Text('Production order')),
      body: Column(
        children: <Widget>[
          if (_isUpdating) const LinearProgressIndicator(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.md),
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
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Progress',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      OrderStatusTimeline(status: order.status),
                      if (hint != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: Text(
                            hint,
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      if (next != null)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: ElevatedButton(
                            onPressed: _isUpdating ? null : () => _advance(next),
                            child: Text(_actionLabel(next)),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Items to produce',
                  child: Column(
                    children: <Widget>[
                      for (final CartItem item in order.items)
                        _ItemRow(item: item),
                      const Divider(),
                      Row(
                        children: <Widget>[
                          Text('Total pieces', style: textTheme.bodyMedium),
                          const Spacer(),
                          Text(
                            '${order.totalPieces}',
                            style: textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (order.status != OrderStatus.cancelled) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  ProductionFilesCard(order: order),
                ],
                const SizedBox(height: AppSpacing.md),
                OrderNotesCard(
                  order: order,
                  viewer: NoteAuthor.manufacturer,
                  factoryId: widget.factoryId,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Customer details and prices are handled by our team.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
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
            width: 72,
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
                const SizedBox(height: AppSpacing.xs),
                Row(
                  children: <Widget>[
                    Container(
                      width: 12,
                      height: 12,
                      margin: const EdgeInsets.only(right: AppSpacing.xs),
                      decoration: BoxDecoration(
                        color: Color(item.colorValue),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        item.summary,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
                if (item.notes.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  Text('Note: ${item.notes}', style: textTheme.bodySmall),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
