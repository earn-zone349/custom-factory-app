import 'order.dart';

/// Rules for how an order may move from one status to the next.
class OrderWorkflow {
  const OrderWorkflow._();

  static const Map<OrderStatus, List<OrderStatus>> _transitions =
      <OrderStatus, List<OrderStatus>>{
    OrderStatus.placed: <OrderStatus>[
      OrderStatus.confirmed,
      OrderStatus.cancelled,
    ],
    OrderStatus.confirmed: <OrderStatus>[
      OrderStatus.inProduction,
      OrderStatus.cancelled,
    ],
    OrderStatus.inProduction: <OrderStatus>[OrderStatus.qualityCheck],
    OrderStatus.qualityCheck: <OrderStatus>[
      OrderStatus.outForDelivery,
      OrderStatus.inProduction,
    ],
    OrderStatus.outForDelivery: <OrderStatus>[OrderStatus.delivered],
    OrderStatus.delivered: <OrderStatus>[],
    OrderStatus.cancelled: <OrderStatus>[],
  };

  /// Statuses an order can move to from [current]. The first one is the
  /// normal step forward.
  static List<OrderStatus> nextOptions(OrderStatus current) {
    return List<OrderStatus>.unmodifiable(
      _transitions[current] ?? const <OrderStatus>[],
    );
  }

  static bool canMove(OrderStatus from, OrderStatus to) {
    return nextOptions(from).contains(to);
  }

  /// Button text for moving an order from [from] to [to].
  static String actionLabel(OrderStatus from, OrderStatus to) {
    if (from == OrderStatus.qualityCheck && to == OrderStatus.inProduction) {
      return 'Failed quality check: back to production';
    }
    return switch (to) {
      OrderStatus.placed => 'Reopen order',
      OrderStatus.confirmed => 'Confirm order',
      OrderStatus.inProduction => 'Start production',
      OrderStatus.qualityCheck => 'Send to quality check',
      OrderStatus.outForDelivery => 'Approve and send for delivery',
      OrderStatus.delivered => 'Mark as delivered',
      OrderStatus.cancelled => 'Cancel order',
    };
  }
}
