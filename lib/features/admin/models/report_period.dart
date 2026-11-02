import '../../orders/models/order.dart';

/// Time ranges the admin can report on.
enum ReportPeriod {
  today('Today'),
  last7Days('Last 7 days'),
  last30Days('Last 30 days'),
  allTime('All time');

  const ReportPeriod(this.label);

  final String label;

  /// First moment of the period in local time, or null for all time.
  DateTime? startFrom(DateTime now) {
    final DateTime midnight = DateTime(now.year, now.month, now.day);
    return switch (this) {
      ReportPeriod.today => midnight,
      ReportPeriod.last7Days =>
        DateTime(midnight.year, midnight.month, midnight.day - 6),
      ReportPeriod.last30Days =>
        DateTime(midnight.year, midnight.month, midnight.day - 29),
      ReportPeriod.allTime => null,
    };
  }

  /// The orders placed within this period (local time), in the same order.
  List<Order> filter(List<Order> orders, DateTime now) {
    final DateTime? start = startFrom(now);
    if (start == null) return List<Order>.of(orders);
    return orders
        .where((Order order) => !order.createdAt.toLocal().isBefore(start))
        .toList();
  }
}
