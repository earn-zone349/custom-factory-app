import 'package:flutter/foundation.dart';

import '../../cart/models/cart_item.dart';
import 'delivery_address.dart';
import 'payment_method.dart';

/// Where an order is in its life. Later steps move orders through these.
enum OrderStatus {
  placed('Order placed'),
  confirmed('Confirmed'),
  inProduction('In production'),
  qualityCheck('Quality check'),
  outForDelivery('Out for delivery'),
  delivered('Delivered'),
  cancelled('Cancelled');

  const OrderStatus(this.label);

  final String label;
}

/// A placed order: what was bought, where it goes and how it is paid.
@immutable
class Order {
  const Order({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.address,
    required this.paymentMethod,
    this.status = OrderStatus.placed,
  });

  /// Parses an order. Throws [FormatException] for invalid data.
  factory Order.fromMap(Map<String, dynamic> map) {
    final Object? rawItems = map['items'];
    if (rawItems is! List<dynamic> || rawItems.isEmpty) {
      throw const FormatException('Order has no items');
    }
    final Object? rawAddress = map['address'];
    if (rawAddress is! Map<String, dynamic>) {
      throw const FormatException('Order has no address');
    }
    return Order(
      id: _readString(map, 'id'),
      createdAt: DateTime.parse(_readString(map, 'createdAt')),
      items: rawItems.map((Object? item) {
        if (item is! Map<String, dynamic>) {
          throw const FormatException('Invalid order item');
        }
        return CartItem.fromMap(item);
      }).toList(),
      address: DeliveryAddress.fromMap(rawAddress),
      paymentMethod: _readEnum(PaymentMethod.values, map, 'paymentMethod'),
      status: _readEnum(OrderStatus.values, map, 'status'),
    );
  }

  final String id;
  final DateTime createdAt;
  final List<CartItem> items;
  final DeliveryAddress address;
  final PaymentMethod paymentMethod;
  final OrderStatus status;

  int get totalPieces {
    return items.fold<int>(0, (int sum, CartItem item) => sum + item.quantity);
  }

  /// Sum of the lines that have an estimated price.
  double get estimatedTotal {
    return items
        .where((CartItem item) => item.hasEstimate)
        .fold<double>(0, (double sum, CartItem item) => sum + item.lineTotal);
  }

  bool get hasUnpricedItems {
    return items.any((CartItem item) => !item.hasEstimate);
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'createdAt': createdAt.toUtc().toIso8601String(),
      'items': items.map((CartItem item) => item.toMap()).toList(),
      'address': address.toMap(),
      'paymentMethod': paymentMethod.name,
      'status': status.name,
    };
  }

  static String _readString(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is String) return value;
    throw FormatException('Invalid or missing "$key"');
  }

  static T _readEnum<T extends Enum>(
    List<T> values,
    Map<String, dynamic> map,
    String key,
  ) {
    final String name = _readString(map, key);
    for (final T value in values) {
      if (value.name == name) return value;
    }
    throw FormatException('Unknown "$key" value "$name"');
  }
}
