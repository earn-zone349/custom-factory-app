import 'package:flutter/foundation.dart';

import '../../admin/models/report_period.dart';
import '../../admin/models/sales_report.dart';
import '../../cart/models/cart_item.dart';
import '../../notes/models/order_note.dart';
import '../../orders/data/order_service.dart';
import '../../orders/models/order.dart';

/// Pieces and orders of one product made by a factory.
@immutable
class FactoryProductLoad {
  const FactoryProductLoad({
    required this.category,
    required this.pieces,
    required this.orders,
  });

  final String category;
  final int pieces;

  /// Number of orders that contain this product.
  final int orders;
}

/// Numbers for one factory's own report. It is built only from the orders
/// assigned to that factory and never contains customer details or prices.
@immutable
class FactoryReport {
  const FactoryReport({
    required this.period,
    required this.orders,
    required this.statusCounts,
    required this.activeOrders,
    required this.cancelledOrders,
    required this.finishedOrders,
    required this.deliveredOrders,
    required this.totalPieces,
    required this.piecesToMake,
    required this.piecesFinished,
    required this.products,
    required this.timeline,
    required this.delayReports,
    required this.delayDaysTotal,
    required this.longestDelayDays,
    required this.openDelays,
    required this.delayedOrders,
    required this.problemReports,
    required this.openProblems,
  });

  factory FactoryReport.build({
    required List<Order> orders,
    required List<OrderNote> notes,
    required String factoryId,
    required ReportPeriod period,
    required DateTime now,
  }) {
    final List<Order> mine = orders
        .where((Order order) => OrderService.isVisibleToFactory(order, factoryId))
        .toList();
    final List<Order> inPeriod = period.filter(mine, now);
    final List<Order> active = inPeriod
        .where((Order order) => order.status != OrderStatus.cancelled)
        .toList();

    final Map<OrderStatus, int> statusCounts = <OrderStatus, int>{
      for (final OrderStatus status in OrderStatus.values) status: 0,
    };
    for (final Order order in inPeriod) {
      statusCounts[order.status] = (statusCounts[order.status] ?? 0) + 1;
    }

    int totalPieces = 0;
    int piecesToMake = 0;
    int piecesFinished = 0;
    int finishedOrders = 0;
    int deliveredOrders = 0;
    // Cancelled orders are not in the active list, so they never count here.
    for (final Order order in active) {
      final int pieces = order.totalPieces;
      totalPieces += pieces;
      switch (order.status) {
        case OrderStatus.placed:
        case OrderStatus.confirmed:
        case OrderStatus.inProduction:
          piecesToMake += pieces;
        case OrderStatus.qualityCheck:
        case OrderStatus.outForDelivery:
          piecesFinished += pieces;
          finishedOrders++;
        case OrderStatus.delivered:
          piecesFinished += pieces;
          finishedOrders++;
          deliveredOrders++;
        case OrderStatus.cancelled:
          break;
      }
    }

    // A note counts only if this factory wrote it for an order it still has.
    final Map<String, Order> activeById = <String, Order>{
      for (final Order order in active) order.id: order,
    };
    int delayReports = 0;
    int delayDaysTotal = 0;
    int longestDelayDays = 0;
    int openDelays = 0;
    int problemReports = 0;
    int openProblems = 0;
    final Set<String> delayedOrderIds = <String>{};
    for (final OrderNote note in notes) {
      final Order? order = activeById[note.orderId];
      if (order == null ||
          note.author != NoteAuthor.manufacturer ||
          note.authorName != order.manufacturerName) {
        continue;
      }
      if (note.kind == NoteKind.delay) {
        final int days = note.delayDays ?? 0;
        delayReports++;
        delayDaysTotal += days;
        if (days > longestDelayDays) longestDelayDays = days;
        if (!note.isResolved) openDelays++;
        delayedOrderIds.add(note.orderId);
      } else if (note.kind == NoteKind.problem) {
        problemReports++;
        if (!note.isResolved) openProblems++;
      }
    }

    return FactoryReport(
      period: period,
      orders: inPeriod,
      statusCounts: statusCounts,
      activeOrders: active.length,
      cancelledOrders: inPeriod.length - active.length,
      finishedOrders: finishedOrders,
      deliveredOrders: deliveredOrders,
      totalPieces: totalPieces,
      piecesToMake: piecesToMake,
      piecesFinished: piecesFinished,
      products: _buildProducts(active),
      // Only the order counts of the chart are used; prices are never shown.
      timeline: SalesReport.build(mine, period: period, now: now).timeline,
      delayReports: delayReports,
      delayDaysTotal: delayDaysTotal,
      longestDelayDays: longestDelayDays,
      openDelays: openDelays,
      delayedOrders: delayedOrderIds.length,
      problemReports: problemReports,
      openProblems: openProblems,
    );
  }

  final ReportPeriod period;

  /// Every order of this factory placed in the period, cancelled ones
  /// included, in the order they were given.
  final List<Order> orders;
  final Map<OrderStatus, int> statusCounts;

  /// Orders that were not cancelled.
  final int activeOrders;
  final int cancelledOrders;

  /// Orders whose production is finished (quality check and later).
  final int finishedOrders;
  final int deliveredOrders;
  final int totalPieces;

  /// Pieces of orders the factory has not finished yet.
  final int piecesToMake;
  final int piecesFinished;

  /// Products with the most pieces first.
  final List<FactoryProductLoad> products;

  /// Orders over time. Empty for the Today period.
  final List<TimelineBucket> timeline;
  final int delayReports;
  final int delayDaysTotal;
  final int longestDelayDays;
  final int openDelays;

  /// Number of different orders the factory reported a delay on.
  final int delayedOrders;
  final int problemReports;
  final int openProblems;

  /// Share of orders with finished production, from 0 to 1.
  double get completionRate {
    return activeOrders == 0 ? 0 : finishedOrders / activeOrders;
  }

  /// Share of orders with a reported delay, from 0 to 1.
  double get delayedOrderRate {
    return activeOrders == 0 ? 0 : delayedOrders / activeOrders;
  }

  /// Average days of the delay reports (0 when there are none).
  double get averageDelayDays {
    return delayReports == 0 ? 0 : delayDaysTotal / delayReports;
  }

  /// Delays and problems that are not resolved yet.
  int get openIssues => openDelays + openProblems;

  static List<FactoryProductLoad> _buildProducts(List<Order> active) {
    final Map<String, int> piecesBy = <String, int>{};
    final Map<String, Set<String>> ordersBy = <String, Set<String>>{};

    for (final Order order in active) {
      for (final CartItem item in order.items) {
        piecesBy[item.category] = (piecesBy[item.category] ?? 0) + item.quantity;
        (ordersBy[item.category] ??= <String>{}).add(order.id);
      }
    }

    final List<FactoryProductLoad> products = piecesBy.entries
        .map(
          (MapEntry<String, int> entry) => FactoryProductLoad(
            category: entry.key,
            pieces: entry.value,
            orders: ordersBy[entry.key]?.length ?? 0,
          ),
        )
        .toList();
    products.sort((FactoryProductLoad a, FactoryProductLoad b) {
      final int byPieces = b.pieces.compareTo(a.pieces);
      if (byPieces != 0) return byPieces;
      return a.category.toLowerCase().compareTo(b.category.toLowerCase());
    });
    return products;
  }
}
