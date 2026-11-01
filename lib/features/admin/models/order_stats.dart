import 'package:flutter/foundation.dart';

import '../../orders/models/order.dart';

/// Order counts and value shown on the admin dashboard.
@immutable
class OrderStats {
  const OrderStats({
    required this.total,
    required this.newOrders,
    required this.inProgress,
    required this.delivered,
    required this.cancelled,
    required this.activeValue,
    required this.hasUnpricedOrders,
  });

  factory OrderStats.from(List<Order> orders) {
    int newOrders = 0;
    int inProgress = 0;
    int delivered = 0;
    int cancelled = 0;
    double activeValue = 0;
    bool hasUnpriced = false;

    for (final Order order in orders) {
      switch (order.status) {
        case OrderStatus.placed:
          newOrders++;
        case OrderStatus.confirmed:
        case OrderStatus.inProduction:
        case OrderStatus.qualityCheck:
        case OrderStatus.outForDelivery:
          inProgress++;
        case OrderStatus.delivered:
          delivered++;
        case OrderStatus.cancelled:
          cancelled++;
      }
      if (order.status != OrderStatus.cancelled) {
        activeValue += order.estimatedTotal;
        if (order.hasUnpricedItems) hasUnpriced = true;
      }
    }

    return OrderStats(
      total: orders.length,
      newOrders: newOrders,
      inProgress: inProgress,
      delivered: delivered,
      cancelled: cancelled,
      activeValue: activeValue,
      hasUnpricedOrders: hasUnpriced,
    );
  }

  final int total;

  /// Orders just placed and waiting to be confirmed.
  final int newOrders;

  /// Confirmed orders that are not yet delivered.
  final int inProgress;
  final int delivered;
  final int cancelled;

  /// Estimated value of all orders that are not cancelled.
  final double activeValue;

  /// True if some counted orders have no price estimate yet.
  final bool hasUnpricedOrders;
}
