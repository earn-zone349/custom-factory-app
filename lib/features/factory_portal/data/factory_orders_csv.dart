import '../../../core/utils/date_formatters.dart';
import '../../admin/data/orders_csv.dart';
import '../../cart/models/cart_item.dart';
import '../../orders/models/order.dart';

/// Builds a CSV file of a factory's own orders. It has no customer details
/// and no prices. It opens correctly in Excel and Google Sheets (UTF-8 with a
/// byte order mark, so Bangla text stays readable).
class FactoryOrdersCsv {
  const FactoryOrdersCsv._();

  static const String _byteOrderMark = '\uFEFF';

  static const List<String> header = <String>[
    'Order number',
    'Date',
    'Status',
    'Items',
    'Pieces',
  ];

  static String build(List<Order> orders) {
    final StringBuffer buffer = StringBuffer(_byteOrderMark);
    buffer.write(_row(header));
    for (final Order order in orders) {
      buffer.write(
        _row(<String>[
          order.id,
          DateFormatters.dateTime(order.createdAt),
          order.status.label,
          _describeItems(order),
          '${order.totalPieces}',
        ]),
      );
    }
    return buffer.toString();
  }

  /// For example "Mug (Ceramic · Red · 11 oz) x 10; Cap (Red) x 5".
  static String _describeItems(Order order) {
    return order.items
        .map(
          (CartItem item) =>
              '${item.category} (${item.summary}) x ${item.quantity}',
        )
        .join('; ');
  }

  static String _row(List<String> fields) {
    return '${fields.map(OrdersCsv.escape).join(',')}\r\n';
  }
}
