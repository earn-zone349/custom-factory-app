import '../../orders/models/order.dart';
import '../../orders/models/order_display.dart';

/// Builds a CSV file of orders that opens correctly in Excel and Google
/// Sheets (UTF-8 with a byte order mark, so Bangla text stays readable).
class OrdersCsv {
  const OrdersCsv._();

  static const String _byteOrderMark = '\uFEFF';

  static const List<String> header = <String>[
    'Order number',
    'Date',
    'Status',
    'Customer',
    'Phone',
    'District',
    'Area',
    'Address',
    'Factory',
    'Items',
    'Pieces',
    'Estimated total (BDT)',
    'Payment',
  ];

  static String build(List<Order> orders) {
    final StringBuffer buffer = StringBuffer(_byteOrderMark);
    buffer.write(_row(header));
    for (final Order order in orders) {
      buffer.write(
        _row(<String>[
          order.id,
          _formatDate(order.createdAt),
          order.status.label,
          order.address.fullName,
          order.address.phone,
          order.address.district,
          order.address.area,
          order.address.addressLine,
          order.manufacturerName ?? '',
          order.itemsSummary,
          '${order.totalPieces}',
          order.estimatedTotal > 0 ? order.estimatedTotal.toStringAsFixed(0) : '',
          order.paymentMethod.label,
        ]),
      );
    }
    return buffer.toString();
  }

  static String _row(List<String> fields) {
    return '${fields.map(escape).join(',')}\r\n';
  }

  /// Makes one value safe for a CSV cell: quotes it when needed and stops
  /// spreadsheet programs from running text that starts like a formula.
  static String escape(String value) {
    String text = value;
    if (text.isNotEmpty && '=+-@\t\r'.contains(text[0])) {
      text = "'$text";
    }
    final bool needsQuotes = text.contains(',') ||
        text.contains('"') ||
        text.contains('\n') ||
        text.contains('\r');
    if (!needsQuotes) return text;
    return '"${text.replaceAll('"', '""')}"';
  }

  static String _formatDate(DateTime value) {
    final DateTime local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
