import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../checkout/checkout_screen.dart';
import '../editor/data/design_document.dart';
import '../editor/data/design_storage.dart';
import '../editor/widgets/design_preview.dart';
import 'cart_controller.dart';
import 'cart_scope.dart';
import 'models/cart_item.dart';

const String _updateFailedMessage =
    'Could not update the cart. Please try again.';

/// Runs a cart change and shows a message if saving fails.
Future<void> _guard(
  BuildContext context,
  Future<void> Function() action,
) async {
  final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
  try {
    await action();
  } on Exception {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(_updateFailedMessage)));
  }
}

/// Shows everything the customer wants to order.
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final CartController cart = CartScope.of(context);

    final Widget body;
    if (!cart.isLoaded) {
      body = const Center(child: CircularProgressIndicator());
    } else if (cart.items.isEmpty) {
      body = const _EmptyCart();
    } else {
      body = _CartList(cart: cart);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Cart')),
      body: body,
      bottomNavigationBar:
          cart.items.isEmpty ? null : _CheckoutBar(cart: cart),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircleAvatar(
              radius: 36,
              backgroundColor: AppColors.primaryLight,
              child: Icon(
                Icons.shopping_cart_outlined,
                size: 36,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Your cart is empty',
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Design a product and it will appear here.',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Browse products'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartList extends StatelessWidget {
  const _CartList({required this.cart});

  final CartController cart;

  @override
  Widget build(BuildContext context) {
    final List<CartItem> items = cart.items;

    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) =>
          const SizedBox(height: AppSpacing.md),
      itemBuilder: (BuildContext context, int index) {
        final CartItem item = items[index];
        return _CartItemCard(
          key: ValueKey<String>(item.id),
          item: item,
          cart: cart,
        );
      },
    );
  }
}

class _CartItemCard extends StatelessWidget {
  const _CartItemCard({super.key, required this.item, required this.cart});

  final CartItem item;
  final CartController cart;

  Future<void> _remove(BuildContext context) async {
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final int index =
        cart.items.indexWhere((CartItem entry) => entry.id == item.id);
    try {
      await cart.remove(item.id);
    } on Exception {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(_updateFailedMessage)));
      return;
    }
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Item removed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => _restore(messenger, index),
          ),
        ),
      );
  }

  Future<void> _restore(ScaffoldMessengerState messenger, int index) async {
    try {
      await cart.restore(item, index);
    } on Exception {
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text(_updateFailedMessage)));
    }
  }

  Future<void> _editQuantity(BuildContext context) async {
    final int? value = await showDialog<int>(
      context: context,
      builder: (BuildContext dialogContext) {
        return _QuantityDialog(initial: item.quantity);
      },
    );
    if (value == null || !context.mounted) return;
    await _guard(context, () => cart.setQuantity(item.id, value));
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String? designId = item.designId;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: 76,
              child: designId == null
                  ? const _ThumbPlaceholder(icon: Icons.inventory_2_outlined)
                  : _DesignThumbnail(designId: designId),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          item.category,
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Remove',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => _remove(context),
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item.summary,
                    style: textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  if (item.notes.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      item.notes,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: <Widget>[
                      IconButton.outlined(
                        visualDensity: VisualDensity.compact,
                        onPressed: item.quantity > CartItem.minQuantity
                            ? () => _guard(
                                  context,
                                  () => cart.setQuantity(
                                    item.id,
                                    item.quantity - 1,
                                  ),
                                )
                            : null,
                        icon: const Icon(Icons.remove_rounded),
                      ),
                      TextButton(
                        onPressed: () => _editQuantity(context),
                        child: Text(
                          '${item.quantity}',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton.outlined(
                        visualDensity: VisualDensity.compact,
                        onPressed: item.quantity < CartItem.maxQuantity
                            ? () => _guard(
                                  context,
                                  () => cart.setQuantity(
                                    item.id,
                                    item.quantity + 1,
                                  ),
                                )
                            : null,
                        icon: const Icon(Icons.add_rounded),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    item.hasEstimate
                        ? 'Est. ${Formatters.price(item.lineTotal)}'
                        : 'Quote after review',
                    style: textTheme.titleSmall?.copyWith(
                      color: AppColors.primaryDark,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Loads the saved design of a cart line and shows a small preview.
class _DesignThumbnail extends StatefulWidget {
  const _DesignThumbnail({required this.designId});

  final String designId;

  @override
  State<_DesignThumbnail> createState() => _DesignThumbnailState();
}

class _DesignThumbnailState extends State<_DesignThumbnail> {
  late final Future<DesignDocument> _future =
      DesignStorage().load(widget.designId);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DesignDocument>(
      future: _future,
      builder: (BuildContext context, AsyncSnapshot<DesignDocument> snapshot) {
        if (snapshot.hasError) {
          return const _ThumbPlaceholder(icon: Icons.broken_image_outlined);
        }
        if (!snapshot.hasData) {
          return const _ThumbPlaceholder(icon: Icons.hourglass_empty_rounded);
        }
        final DesignDocument document = snapshot.requireData;
        return DesignPreview(
          elements: document.elements,
          baseColor: document.baseColor,
        );
      },
    );
  }
}

class _ThumbPlaceholder extends StatelessWidget {
  const _ThumbPlaceholder({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 360 / 420,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
        child: Icon(icon, color: AppColors.primary),
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  const _CheckoutBar({required this.cart});

  final CartController cart;

  /// Opens checkout for everything in the cart.
  void _checkout(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CheckoutScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final double total = cart.estimatedTotal;
    final String totalText =
        total > 0 ? Formatters.price(total) : 'Quote after review';
    final String note = cart.hasUnpricedItems && total > 0
        ? 'Some items will be quoted after review. Final price is confirmed by the factory.'
        : 'Final price is confirmed after factory review.';

    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                note,
                style: textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Estimated total',
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                      ),
                      Text(
                        totalText,
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _checkout(context),
                      child: const Text('Checkout'),
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

/// Dialog to type an exact quantity (for large orders).
class _QuantityDialog extends StatefulWidget {
  const _QuantityDialog({required this.initial});

  final int initial;

  @override
  State<_QuantityDialog> createState() => _QuantityDialogState();
}

class _QuantityDialogState extends State<_QuantityDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final int? value = int.tryParse(_controller.text.trim());
    if (value == null ||
        value < CartItem.minQuantity ||
        value > CartItem.maxQuantity) {
      setState(() {
        _error =
            'Enter a number from ${CartItem.minQuantity} to ${CartItem.maxQuantity}';
      });
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quantity'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(errorText: _error),
        onSubmitted: (_) => _submit(),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('OK')),
      ],
    );
  }
}
