import 'package:flutter/foundation.dart';

import '../../cart/models/cart_item.dart';
import '../../orders/models/order.dart';
import 'report_period.dart';

/// Sales of one product category.
@immutable
class ProductSales {
  const ProductSales({
    required this.category,
    required this.pieces,
    required this.value,
    required this.orders,
  });

  final String category;
  final int pieces;

  /// Estimated value of the lines that have a price.
  final double value;

  /// Number of orders that contain this product.
  final int orders;
}

/// How much work one factory has been given.
@immutable
class FactoryLoad {
  const FactoryLoad({
    required this.id,
    required this.name,
    required this.orders,
    required this.pieces,
  });

  final String id;
  final String name;
  final int orders;
  final int pieces;
}

/// One bar of the orders chart (a day or a month).
@immutable
class TimelineBucket {
  const TimelineBucket({
    required this.label,
    required this.orders,
    required this.value,
  });

  final String label;
  final int orders;
  final double value;
}

/// Numbers for the admin reports page. Built from the orders of one period;
/// cancelled orders are counted separately and never add to sales.
@immutable
class SalesReport {
  const SalesReport({
    required this.period,
    required this.periodOrders,
    required this.activeOrders,
    required this.cancelledOrders,
    required this.deliveredOrders,
    required this.totalPieces,
    required this.estimatedRevenue,
    required this.deliveredRevenue,
    required this.averageOrderValue,
    required this.hasUnpricedOrders,
    required this.cancellationRate,
    required this.statusCounts,
    required this.products,
    required this.factories,
    required this.waitingForFactory,
    required this.timeline,
  });

  factory SalesReport.build(
    List<Order> allOrders, {
    required ReportPeriod period,
    required DateTime now,
  }) {
    final List<Order> inPeriod = period.filter(allOrders, now);
    final List<Order> active = inPeriod
        .where((Order order) => order.status != OrderStatus.cancelled)
        .toList();
    final List<Order> delivered = inPeriod
        .where((Order order) => order.status == OrderStatus.delivered)
        .toList();

    final Map<OrderStatus, int> statusCounts = <OrderStatus, int>{
      for (final OrderStatus status in OrderStatus.values) status: 0,
    };
    for (final Order order in inPeriod) {
      statusCounts[order.status] = (statusCounts[order.status] ?? 0) + 1;
    }

    int pieces = 0;
    int pricedOrders = 0;
    double revenue = 0;
    bool hasUnpriced = false;
    for (final Order order in active) {
      pieces += order.totalPieces;
      revenue += order.estimatedTotal;
      if (order.estimatedTotal > 0) pricedOrders++;
      if (order.hasUnpricedItems) hasUnpriced = true;
    }
    final double deliveredRevenue = delivered.fold<double>(
      0,
      (double sum, Order order) => sum + order.estimatedTotal,
    );

    return SalesReport(
      period: period,
      periodOrders: inPeriod,
      activeOrders: active.length,
      cancelledOrders: inPeriod.length - active.length,
      deliveredOrders: delivered.length,
      totalPieces: pieces,
      estimatedRevenue: revenue,
      deliveredRevenue: deliveredRevenue,
      averageOrderValue: pricedOrders == 0 ? 0 : revenue / pricedOrders,
      hasUnpricedOrders: hasUnpriced,
      cancellationRate: inPeriod.isEmpty
          ? 0
          : (inPeriod.length - active.length) / inPeriod.length,
      statusCounts: statusCounts,
      products: _buildProducts(active),
      factories: _buildFactories(active),
      waitingForFactory: _countWaiting(active),
      timeline: _buildTimeline(active, period, now),
    );
  }

  final ReportPeriod period;

  /// Every order placed in the period, cancelled ones included.
  final List<Order> periodOrders;

  /// Orders that were not cancelled.
  final int activeOrders;
  final int cancelledOrders;
  final int deliveredOrders;
  final int totalPieces;

  /// Estimated value of the orders that were not cancelled.
  final double estimatedRevenue;
  final double deliveredRevenue;

  /// Average estimated value of the orders that have a price.
  final double averageOrderValue;

  /// True if some counted orders have no price estimate.
  final bool hasUnpricedOrders;

  /// Share of cancelled orders, from 0 to 1.
  final double cancellationRate;
  final Map<OrderStatus, int> statusCounts;

  /// Best selling products first.
  final List<ProductSales> products;

  /// Busiest factories first.
  final List<FactoryLoad> factories;

  /// Orders that still need a factory before production can start.
  final int waitingForFactory;

  /// Orders over time. Empty for the "Today" period.
  final List<TimelineBucket> timeline;

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static List<ProductSales> _buildProducts(List<Order> active) {
    final Map<String, int> piecesBy = <String, int>{};
    final Map<String, double> valueBy = <String, double>{};
    final Map<String, Set<String>> ordersBy = <String, Set<String>>{};

    for (final Order order in active) {
      for (final CartItem item in order.items) {
        piecesBy[item.category] = (piecesBy[item.category] ?? 0) + item.quantity;
        if (item.hasEstimate) {
          valueBy[item.category] = (valueBy[item.category] ?? 0) + item.lineTotal;
        }
        (ordersBy[item.category] ??= <String>{}).add(order.id);
      }
    }

    final List<ProductSales> products = piecesBy.entries
        .map(
          (MapEntry<String, int> entry) => ProductSales(
            category: entry.key,
            pieces: entry.value,
            value: valueBy[entry.key] ?? 0,
            orders: ordersBy[entry.key]?.length ?? 0,
          ),
        )
        .toList();
    products.sort((ProductSales a, ProductSales b) {
      final int byPieces = b.pieces.compareTo(a.pieces);
      if (byPieces != 0) return byPieces;
      return a.category.toLowerCase().compareTo(b.category.toLowerCase());
    });
    return products;
  }

  static List<FactoryLoad> _buildFactories(List<Order> active) {
    final Map<String, String> names = <String, String>{};
    final Map<String, int> ordersBy = <String, int>{};
    final Map<String, int> piecesBy = <String, int>{};

    for (final Order order in active) {
      final String? id = order.manufacturerId;
      if (id == null) continue;
      names[id] = order.manufacturerName ?? id;
      ordersBy[id] = (ordersBy[id] ?? 0) + 1;
      piecesBy[id] = (piecesBy[id] ?? 0) + order.totalPieces;
    }

    final List<FactoryLoad> factories = ordersBy.entries
        .map(
          (MapEntry<String, int> entry) => FactoryLoad(
            id: entry.key,
            name: names[entry.key] ?? entry.key,
            orders: entry.value,
            pieces: piecesBy[entry.key] ?? 0,
          ),
        )
        .toList();
    factories.sort((FactoryLoad a, FactoryLoad b) {
      final int byOrders = b.orders.compareTo(a.orders);
      if (byOrders != 0) return byOrders;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return factories;
  }

  static int _countWaiting(List<Order> active) {
    return active
        .where(
          (Order order) =>
              order.manufacturerId == null &&
              (order.status == OrderStatus.placed ||
                  order.status == OrderStatus.confirmed),
        )
        .length;
  }

  static List<TimelineBucket> _buildTimeline(
    List<Order> active,
    ReportPeriod period,
    DateTime now,
  ) {
    switch (period) {
      case ReportPeriod.today:
        return const <TimelineBucket>[];
      case ReportPeriod.last7Days:
        return _daily(active, now, 7);
      case ReportPeriod.last30Days:
        return _daily(active, now, 30);
      case ReportPeriod.allTime:
        return _monthly(active, now, 12);
    }
  }

  static int _dayDifference(DateTime from, DateTime to) {
    return DateTime.utc(to.year, to.month, to.day)
        .difference(DateTime.utc(from.year, from.month, from.day))
        .inDays;
  }

  static List<TimelineBucket> _daily(
    List<Order> active,
    DateTime now,
    int days,
  ) {
    final DateTime first = DateTime(now.year, now.month, now.day - (days - 1));
    final List<int> counts = List<int>.filled(days, 0);
    final List<double> values = List<double>.filled(days, 0);

    for (final Order order in active) {
      final DateTime local = order.createdAt.toLocal();
      final int index = _dayDifference(first, local);
      if (index < 0 || index >= days) continue;
      counts[index]++;
      values[index] += order.estimatedTotal;
    }

    return <TimelineBucket>[
      for (int i = 0; i < days; i++)
        TimelineBucket(
          label: _dayLabel(DateTime(first.year, first.month, first.day + i)),
          orders: counts[i],
          value: values[i],
        ),
    ];
  }

  static String _dayLabel(DateTime day) => '${day.day} ${_months[day.month - 1]}';

  static int _monthIndex(DateTime date) => date.year * 12 + (date.month - 1);

  static List<TimelineBucket> _monthly(
    List<Order> active,
    DateTime now,
    int maxMonths,
  ) {
    if (active.isEmpty) return const <TimelineBucket>[];

    final int current = _monthIndex(now);
    int earliest = current;
    for (final Order order in active) {
      final int index = _monthIndex(order.createdAt.toLocal());
      if (index < earliest) earliest = index;
    }
    final int oldestAllowed = current - (maxMonths - 1);
    final int first = earliest < oldestAllowed ? oldestAllowed : earliest;
    final int count = current - first + 1;

    final List<int> counts = List<int>.filled(count, 0);
    final List<double> values = List<double>.filled(count, 0);
    for (final Order order in active) {
      final int index = _monthIndex(order.createdAt.toLocal()) - first;
      if (index < 0 || index >= count) continue;
      counts[index]++;
      values[index] += order.estimatedTotal;
    }

    return <TimelineBucket>[
      for (int i = 0; i < count; i++)
        TimelineBucket(
          label: _monthLabel(first + i),
          orders: counts[i],
          value: values[i],
        ),
    ];
  }

  static String _monthLabel(int monthIndex) {
    final int year = monthIndex ~/ 12;
    final int month = monthIndex % 12;
    final String shortYear = (year % 100).toString().padLeft(2, '0');
    return '${_months[month]} $shortYear';
  }
}
