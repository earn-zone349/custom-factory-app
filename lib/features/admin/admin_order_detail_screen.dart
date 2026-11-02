import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/date_formatters.dart';
import '../../core/utils/formatters.dart';
import '../cart/models/cart_item.dart';
import '../manufacturers/manufacturer_controller.dart';
import '../manufacturers/manufacturer_scope.dart';
import '../manufacturers/models/manufacturer.dart';
import '../orders/data/order_service.dart';
import '../orders/models/order.dart';
import '../orders/models/order_display.dart';
import '../orders/models/order_workflow.dart';
import '../orders/widgets/order_status_chip.dart';
import '../orders/widgets/order_status_timeline.dart';
import '../orders/widgets/saved_design_thumbnail.dart';
import 'widgets/factory_picker_sheet.dart';

/// One order as the admin sees it: customer, items and status controls.
class AdminOrderDetailScreen extends StatefulWidget {
  const AdminOrderDetailScreen({
    super.key,
    required this.order,
    required this.service,
  });

  final Order order;
  final OrderService service;

  @override
  State<AdminOrderDetailScreen> createState() =>
      _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late Order _order = widget.order;
  bool _isUpdating = false;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(String text, String successMessage) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    String message = successMessage;
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } on Exception {
      message = 'Could not copy';
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _confirmCancel() async {
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
    return confirmed ?? false;
  }

  Future<void> _changeStatus(OrderStatus next) async {
    if (_isUpdating) return;
    if (next == OrderStatus.cancelled) {
      final bool confirmed = await _confirmCancel();
      if (!confirmed || !mounted) return;
    }

    setState(() => _isUpdating = true);
    try {
      final Order updated = await widget.service.changeStatus(
        _order.id,
        next,
      );
      if (!mounted) return;
      setState(() => _order = updated);
      _showMessage('Status changed to ${next.label}');
    } on StateError {
      if (!mounted) return;
      _showMessage('This change is not allowed any more.');
    } on Exception {
      if (!mounted) return;
      _showMessage('Could not update the order. Please try again.');
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  /// Lets the admin pick (or remove) the factory for this order.
  Future<void> _chooseFactory() async {
    if (_isUpdating) return;
    final ManufacturerController factories = ManufacturerScope.of(context);
    final Order current = _order;
    final Set<String> orderCategories =
        current.items.map((CartItem item) => item.category).toSet();

    final FactoryChoice? choice = await showFactoryPicker(
      context,
      factories: factories.activeEntries,
      requiredCategories: orderCategories,
      selectedId: current.manufacturerId,
      canRemove: current.manufacturerId != null,
    );
    if (choice == null || !mounted) return;

    final Manufacturer? selected = choice.manufacturer;
    setState(() => _isUpdating = true);
    try {
      final Order updated =
          await widget.service.assignManufacturer(current.id, selected);
      if (!mounted) return;
      setState(() => _order = updated);
      _showMessage(
        selected == null ? 'Factory removed' : 'Assigned to ${selected.name}',
      );
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

  /// The Factory card: who produces this order and how to reach them.
  Widget _buildFactorySection(Order order) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? name = order.manufacturerName;
    final String? factoryId = order.manufacturerId;
    final Manufacturer? partner = factoryId == null
        ? null
        : ManufacturerScope.maybeOf(context)?.byId(factoryId);
    final bool canChange = OrderService.canAssignFactory(order);
    final bool mustAssign =
        name == null && order.status == OrderStatus.confirmed;

    return _SectionCard(
      title: 'Factory',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            name ?? 'Not assigned yet',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (partner != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            _InfoRow(label: 'Contact', value: partner.contactPerson),
            _InfoRow(
              label: 'Phone',
              value: partner.phone,
              onCopy: () => _copy(partner.phone, 'Phone number copied'),
            ),
            _InfoRow(label: 'Location', value: partner.district),
          ],
          if (mustAssign) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Assign a factory before starting production.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.error),
            ),
          ],
          if (canChange) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _isUpdating ? null : _chooseFactory,
              icon: const Icon(Icons.factory_outlined),
              label: Text(name == null ? 'Assign factory' : 'Change factory'),
            ),
          ] else if (name != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'The factory cannot be changed after production starts.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAction(Order order, List<OrderStatus> options, OrderStatus next) {
    final bool isCancel = next == OrderStatus.cancelled;
    final bool isPrimary = !isCancel && next == options.first;
    final String label = OrderWorkflow.actionLabel(order.status, next);
    final bool needsFactory =
        next == OrderStatus.inProduction && order.manufacturerId == null;
    final VoidCallback? onPressed =
        (_isUpdating || needsFactory) ? null : () => _changeStatus(next);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: isPrimary
          ? ElevatedButton(onPressed: onPressed, child: Text(label))
          : OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: isCancel ? AppColors.error : null,
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: onPressed,
              child: Text(label),
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Order order = _order;
    final List<OrderStatus> options = OrderWorkflow.nextOptions(order.status);

    return Scaffold(
      appBar: AppBar(title: const Text('Manage order')),
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
                          onPressed: () =>
                              _copy(order.id, 'Order number copied'),
                          icon: const Icon(Icons.copy_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Update status',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      OrderStatusTimeline(status: order.status),
                      if (options.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.md),
                          child: Text(
                            'No further changes are possible for this order.',
                            style: textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ),
                      for (final OrderStatus next in options)
                        _buildAction(order, options, next),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildFactorySection(order),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Customer',
                  child: Column(
                    children: <Widget>[
                      _InfoRow(label: 'Name', value: order.address.fullName),
                      _InfoRow(
                        label: 'Phone',
                        value: order.address.phone,
                        onCopy: () => _copy(
                          order.address.phone,
                          'Phone number copied',
                        ),
                      ),
                      _InfoRow(
                        label: 'Address',
                        value: order.address.formatted,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _SectionCard(
                  title: 'Items',
                  child: Column(
                    children: <Widget>[
                      for (final CartItem item in order.items)
                        _ItemRow(item: item),
                      const Divider(),
                      _InfoRow(
                        label: 'Total pieces',
                        value: '${order.totalPieces}',
                      ),
                      _InfoRow(
                        label: 'Estimated total',
                        value: order.totalText,
                      ),
                      _InfoRow(
                        label: 'Payment',
                        value: order.paymentMethod.label,
                      ),
                    ],
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
  const _InfoRow({required this.label, required this.value, this.onCopy});

  final String label;
  final String value;
  final VoidCallback? onCopy;

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
          if (onCopy != null)
            InkWell(
              onTap: onCopy,
              borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
              child: const Padding(
                padding: EdgeInsets.all(AppSpacing.xs),
                child: Icon(Icons.copy_rounded, size: 18),
              ),
            ),
        ],
      ),
    );
  }
}
