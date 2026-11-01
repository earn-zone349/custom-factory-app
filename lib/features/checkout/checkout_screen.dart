import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_spacing.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/validators.dart';
import '../cart/cart_controller.dart';
import '../cart/cart_scope.dart';
import '../cart/models/cart_item.dart';
import '../orders/data/address_storage.dart';
import '../orders/data/order_service.dart';
import '../orders/models/delivery_address.dart';
import '../orders/models/order.dart';
import '../orders/models/payment_method.dart';
import 'order_confirmation_screen.dart';
import 'widgets/district_picker.dart';

/// Collects the delivery address and payment method, then places the order.
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  static const int _minAddressLength = 10;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _landmarkController = TextEditingController();
  final AddressStorage _addressStorage = AddressStorage();
  late final OrderService _orderService =
      OrderService(addressStorage: _addressStorage);

  String? _district;
  PaymentMethod _payment = PaymentMethod.cashOnDelivery;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _loadSavedAddress();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _areaController.dispose();
    _addressController.dispose();
    _landmarkController.dispose();
    super.dispose();
  }

  /// Fills the form with the address used last time (if any).
  Future<void> _loadSavedAddress() async {
    try {
      final DeliveryAddress? saved = await _addressStorage.read();
      if (saved == null || !mounted) return;
      final bool alreadyTyping = _nameController.text.isNotEmpty ||
          _phoneController.text.isNotEmpty ||
          _areaController.text.isNotEmpty ||
          _addressController.text.isNotEmpty;
      if (alreadyTyping) return;
      setState(() {
        _nameController.text = saved.fullName;
        _phoneController.text = saved.phone;
        _district = saved.district;
        _areaController.text = saved.area;
        _addressController.text = saved.addressLine;
        _landmarkController.text = saved.landmark;
      });
    } on Exception catch (error) {
      debugPrint('Could not load the saved address: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickDistrict(FormFieldState<String> field) async {
    final String? picked = await showDistrictPicker(
      context,
      selected: _district,
    );
    if (picked == null || !mounted) return;
    setState(() => _district = picked);
    field.didChange(picked);
  }

  Future<void> _placeOrder() async {
    if (_isSubmitting) return;
    final FormState? form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    final CartController cart = CartScope.of(context);
    final List<CartItem> items = cart.items;
    final String? district = _district;
    if (items.isEmpty) {
      _showMessage('Your cart is empty.');
      return;
    }
    if (district == null) return;

    final NavigatorState navigator = Navigator.of(context);
    final DeliveryAddress address = DeliveryAddress(
      fullName: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      district: district,
      area: _areaController.text.trim(),
      addressLine: _addressController.text.trim(),
      landmark: _landmarkController.text.trim(),
    );

    setState(() => _isSubmitting = true);
    try {
      final Order order = await _orderService.placeOrder(
        items: items,
        address: address,
        paymentMethod: _payment,
      );

      // The order is saved. A failure to empty the cart must not hide that.
      try {
        await cart.clear();
      } on Exception catch (error) {
        debugPrint('Order placed but the cart could not be cleared: $error');
      }

      if (!mounted) return;
      navigator.pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => OrderConfirmationScreen(order: order),
        ),
      );
    } on Object catch (error) {
      debugPrint('Could not place the order: $error');
      if (!mounted) return;
      _showMessage('Could not place your order. Please try again.');
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CartController cart = CartScope.of(context);
    final bool hasItems = cart.items.isNotEmpty;
    final double total = cart.estimatedTotal;
    final String totalText =
        total > 0 ? Formatters.price(total) : 'Quote after review';

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: !hasItems
          ? const Center(child: Text('Your cart is empty'))
          : AbsorbPointer(
              absorbing: _isSubmitting,
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  children: <Widget>[
                    const _SectionTitle('Order summary'),
                    _OrderSummary(cart: cart, totalText: totalText),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionTitle('Delivery address'),
                    ..._buildAddressFields(),
                    const SizedBox(height: AppSpacing.lg),
                    const _SectionTitle('Payment'),
                    for (final PaymentMethod method in PaymentMethod.values)
                      _PaymentTile(
                        method: method,
                        isSelected: method == _payment,
                        onTap: () => setState(() => _payment = method),
                      ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Final price and delivery charge are confirmed by our team before production.',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.textMuted,
                          ),
                    ),
                  ],
                ),
              ),
            ),
      bottomNavigationBar: !hasItems
          ? null
          : _PlaceOrderBar(
              totalText: totalText,
              isSubmitting: _isSubmitting,
              onPlaceOrder: _placeOrder,
            ),
    );
  }

  List<Widget> _buildAddressFields() {
    return <Widget>[
      const SizedBox(height: AppSpacing.sm),
      TextFormField(
        controller: _nameController,
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.words,
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(60),
        ],
        decoration: const InputDecoration(
          labelText: 'Full name',
          prefixIcon: Icon(Icons.person_outline_rounded),
        ),
        validator: (String? value) {
          if ((value ?? '').trim().length < 2) return 'Enter your full name';
          return null;
        },
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        textInputAction: TextInputAction.next,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(11),
        ],
        decoration: const InputDecoration(
          labelText: 'Phone number',
          hintText: '01XXXXXXXXX',
          prefixIcon: Icon(Icons.phone_outlined),
        ),
        validator: Validators.phone,
      ),
      const SizedBox(height: AppSpacing.md),
      FormField<String>(
        validator: (String? _) {
          return _district == null ? 'Select your district' : null;
        },
        builder: (FormFieldState<String> field) {
          return InkWell(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            onTap: () => _pickDistrict(field),
            child: InputDecorator(
              isEmpty: _district == null,
              decoration: InputDecoration(
                labelText: 'District',
                prefixIcon: const Icon(Icons.map_outlined),
                suffixIcon: const Icon(Icons.arrow_drop_down_rounded),
                errorText: field.errorText,
              ),
              child: Text(_district ?? ''),
            ),
          );
        },
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        controller: _areaController,
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.words,
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(60),
        ],
        decoration: const InputDecoration(
          labelText: 'Area / Thana',
          prefixIcon: Icon(Icons.location_city_outlined),
        ),
        validator: (String? value) =>
            Validators.requiredField(value, label: 'Area'),
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        controller: _addressController,
        maxLines: 3,
        textInputAction: TextInputAction.next,
        textCapitalization: TextCapitalization.sentences,
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(200),
        ],
        decoration: const InputDecoration(
          labelText: 'Full address',
          hintText: 'House, road, village or neighborhood',
          prefixIcon: Icon(Icons.home_outlined),
        ),
        validator: (String? value) {
          if ((value ?? '').trim().length < _minAddressLength) {
            return 'Enter your full address (house, road, area)';
          }
          return null;
        },
      ),
      const SizedBox(height: AppSpacing.md),
      TextFormField(
        controller: _landmarkController,
        textInputAction: TextInputAction.done,
        inputFormatters: <TextInputFormatter>[
          LengthLimitingTextInputFormatter(100),
        ],
        decoration: const InputDecoration(
          labelText: 'Landmark (optional)',
          prefixIcon: Icon(Icons.flag_outlined),
        ),
      ),
    ];
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  const _OrderSummary({required this.cart, required this.totalText});

  final CartController cart;
  final String totalText;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: <Widget>[
            for (final CartItem item in cart.items) _SummaryLine(item: item),
            const Divider(),
            Row(
              children: <Widget>[
                Text(
                  'Estimated total',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  totalText,
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
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
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
              ],
            ),
          ),
          Text(
            item.hasEstimate
                ? Formatters.price(item.lineTotal)
                : 'Quote after review',
            style: textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _PaymentTile extends StatelessWidget {
  const _PaymentTile({
    required this.method,
    required this.isSelected,
    required this.onTap,
  });

  final PaymentMethod method;
  final bool isSelected;
  final VoidCallback onTap;

  IconData get _icon {
    return switch (method) {
      PaymentMethod.cashOnDelivery => Icons.payments_outlined,
      PaymentMethod.bkash || PaymentMethod.nagad =>
        Icons.account_balance_wallet_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    final bool enabled = method.isAvailable;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Card(
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            side: BorderSide(
              color: isSelected && enabled
                  ? AppColors.primary
                  : AppColors.border,
              width: isSelected && enabled ? 2 : 1,
            ),
          ),
          child: ListTile(
            enabled: enabled,
            onTap: enabled ? onTap : null,
            leading: Icon(_icon),
            title: Text(method.label),
            subtitle: Text(method.description),
            trailing: !enabled
                ? const Text('Coming soon')
                : isSelected
                    ? const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.primary,
                      )
                    : const Icon(Icons.circle_outlined),
          ),
        ),
      ),
    );
  }
}

class _PlaceOrderBar extends StatelessWidget {
  const _PlaceOrderBar({
    required this.totalText,
    required this.isSubmitting,
    required this.onPlaceOrder,
  });

  final String totalText;
  final bool isSubmitting;
  final VoidCallback onPlaceOrder;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Material(
      color: AppColors.surface,
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
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
                  onPressed: isSubmitting ? null : onPlaceOrder,
                  child: isSubmitting
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Place order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
