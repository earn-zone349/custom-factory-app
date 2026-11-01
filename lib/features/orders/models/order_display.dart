import '../../../core/utils/formatters.dart';
import '../../cart/models/cart_item.dart';
import 'order.dart';

/// Text shown for an order in lists and detail pages.
extension OrderDisplay on Order {
  /// The estimated total, or a note when the price is quoted later.
  String get totalText {
    return estimatedTotal > 0
        ? Formatters.price(estimatedTotal)
        : 'Quote after review';
  }

  /// For example "Mug x 10, T-Shirt x 5".
  String get itemsSummary {
    return items
        .map((CartItem item) => '${item.category} x ${item.quantity}')
        .join(', ');
  }
}
