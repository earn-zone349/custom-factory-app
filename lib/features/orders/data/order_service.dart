import 'package:flutter/foundation.dart';

import '../../cart/models/cart_item.dart';
import '../../manufacturers/models/manufacturer.dart';
import '../models/delivery_address.dart';
import '../models/order.dart';
import '../models/order_workflow.dart';
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

  /// True while an order can still be cancelled (before it is confirmed).
  static bool canCancel(Order order) => order.status == OrderStatus.placed;

  /// All saved orders, newest first.
  Future<List<Order>> listOrders() => _orders.read();

  /// One order by id, or null if it does not exist.
  Future<Order?> findOrder(String id) async {
    final List<Order> orders = await _orders.read();
    for (final Order order in orders) {
      if (order.id == id) return order;
    }
    return null;
  }

  /// Cancels an order that has not been confirmed yet.
  /// Throws [StateError] if the order is missing or can no longer be cancelled.
  Future<void> cancelOrder(String id) async {
    final Order? order = await findOrder(id);
    if (order == null) throw StateError('Order $id was not found');
    if (!canCancel(order)) {
      throw StateError('Only a newly placed order can be cancelled');
    }
    final bool changed = await _orders.updateStatus(id, OrderStatus.cancelled);
    if (!changed) throw StateError('Order $id was not found');
  }

  /// Moves an order to its next status (used by the admin panel).
  /// Throws StateError if the order is missing or the move is not allowed.
  Future<Order> changeStatus(String id, OrderStatus next) async {
    final Order? order = await findOrder(id);
    if (order == null) throw StateError('Order $id was not found');
    if (!OrderWorkflow.canMove(order.status, next)) {
      throw StateError(
        'Cannot move an order from ${order.status.name} to ${next.name}',
      );
    }
    if (next == OrderStatus.inProduction && order.manufacturerId == null) {
      throw StateError('Assign a factory before starting production');
    }
    final bool changed = await _orders.updateStatus(id, next);
    if (!changed) throw StateError('Order $id was not found');
    final Order? updated = await findOrder(id);
    if (updated == null) throw StateError('Order $id was not found');
    return updated;
  }

  /// True while the factory can still be assigned or changed
  /// (before production starts).
  static bool canAssignFactory(Order order) {
    return order.status == OrderStatus.placed ||
        order.status == OrderStatus.confirmed;
  }

  /// Assigns a factory to an order, or removes it when [manufacturer] is
  /// null. Throws StateError if the order is missing, production has
  /// started, the factory is inactive or it does not make every product.
  Future<Order> assignManufacturer(String id, Manufacturer? manufacturer) async {
    final Order? order = await findOrder(id);
    if (order == null) throw StateError('Order $id was not found');
    if (!canAssignFactory(order)) {
      throw StateError('The factory can no longer be changed for this order');
    }
    if (manufacturer != null) {
      if (!manufacturer.isActive) {
        throw StateError('This factory is not active');
      }
      final Set<String> needed =
          order.items.map((CartItem item) => item.category).toSet();
      final List<String> missing = manufacturer.missingFor(needed);
      if (missing.isNotEmpty) {
        throw StateError('This factory does not make: ${missing.join(', ')}');
      }
    }
    final bool changed = await _orders.assignManufacturer(
      id,
      manufacturer?.id,
      manufacturer?.name,
    );
    if (!changed) throw StateError('Order $id was not found');
    final Order? updated = await findOrder(id);
    if (updated == null) throw StateError('Order $id was not found');
    return updated;
  }

  static String _generateId(DateTime now) {
    final String code = now.millisecondsSinceEpoch.toRadixString(36);
    return 'CF-${code.toUpperCase()}';
  }
}
