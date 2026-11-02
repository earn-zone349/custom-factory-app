import 'dart:typed_data';

/// Everything printed on one page of a production sheet (one order item).
/// It holds no customer details or prices on purpose: a factory only gets
/// what it needs to produce the item.
class ProductionSheetPage {
  const ProductionSheetPage({
    required this.orderId,
    required this.orderDate,
    required this.factoryName,
    required this.itemNumber,
    required this.itemCount,
    required this.category,
    required this.colorName,
    required this.colorValue,
    required this.quantity,
    this.style,
    this.size,
    this.notes = '',
    this.designPng,
  });

  final String orderId;
  final String orderDate;
  final String factoryName;

  /// Position of this item in the order, starting at 1.
  final int itemNumber;
  final int itemCount;
  final String category;
  final String? style;
  final String? size;
  final String colorName;

  /// ARGB value of the product color.
  final int colorValue;
  final int quantity;
  final String notes;

  /// Transparent PNG of the design, or null when it is not available.
  final Uint8List? designPng;
}
