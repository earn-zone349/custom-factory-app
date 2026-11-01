import 'package:flutter/foundation.dart';

import '../../cart/models/cart_item.dart';
import '../models/delivery_address.dart';
import '../models/order.dart';
import '../models/payment_method.dart';
import 'address_storage.dart';
import 'order_storage.dart';

/// Turns a cart into a saved order.
class OrderService {
  OrderService({
    OrderStorage? orderStorage,
    AddressStorage? addressStorage,
    DateTime Function()? clock,
  })  : _orders = orderStorage ?? OrderStorage(),
        _addresses = addressStorage ?? AddressStorage(),
        _clock = clock ?? DateTime.now;

  final OrderStorage _orders;
  final AddressStorage _addresses;
  final DateTime Function() _clock;

  /// Creates and saves an order. Throws [ArgumentError] for an empty cart or
  /// a payment method that is not available yet.
  Future<Order> placeOrder({
    required List<CartItem> items,
    required DeliveryAddress address,
    required PaymentMethod paymentMethod,
  }) async {
    if (items.isEmpty) {
      throw ArgumentError.value(items, 'items', 'An order needs an item');
    }
    if (!paymentMethod.isAvailable) {
      throw ArgumentError.value(
        paymentMethod,
        'paymentMethod',
        'This payment method is not available yet',
      );
    }

    final DateTime now = _clock();
    final Order order = Order(
      id: _generateId(now),
      createdAt: now,
      items: List<CartItem>.unmodifiable(items),
      address: address,
      paymentMethod: paymentMethod,
    );

    await _orders.add(order);

    // Remembering the address is a convenience; it must never fail an order.
    try {
      await _addresses.save(address);
    } on Exception catch (error) {
      debugPrint('Could not remember the address: $error');
    }
    return order;
  }

  static String _generateId(DateTime now) {
    final String code = now.millisecondsSinceEpoch.toRadixString(36);
    return 'CF-${code.toUpperCase()}';
  }
}
