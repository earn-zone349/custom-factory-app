import '../../orders/models/order.dart';

/// Groups of orders a factory can look at.
enum FactoryOrderFilter {
  allActive('All active', <OrderStatus>{
    OrderStatus.confirmed,
    OrderStatus.inProduction,
    OrderStatus.qualityCheck,
    OrderStatus.outForDelivery,
  }),
  toStart('To start', <OrderStatus>{OrderStatus.confirmed}),
  inProduction('In production', <OrderStatus>{OrderStatus.inProduction}),
  delivered('Delivered', <OrderStatus>{OrderStatus.delivered}),
  cancelled('Cancelled', <OrderStatus>{OrderStatus.cancelled});

  const FactoryOrderFilter(this.label, this.statuses);

  final String label;
  final Set<OrderStatus> statuses;

  bool matches(Order order) => statuses.contains(order.status);
}
