import 'package:flutter/foundation.dart';

/// One line in the cart: a configured product plus its saved design.
@immutable
class CartItem {
  const CartItem({
    required this.id,
    required this.category,
    required this.colorName,
    required this.colorValue,
    required this.quantity,
    required this.unitPrice,
    this.style,
    this.size,
    this.notes = '',
    this.designId,
  });

  /// Parses a cart line. Throws [FormatException] for invalid data.
  factory CartItem.fromMap(Map<String, dynamic> map) {
    final int quantity = _readInt(map, 'quantity');
    if (quantity < minQuantity || quantity > maxQuantity) {
      throw const FormatException('Quantity is out of range');
    }
    return CartItem(
      id: _readString(map, 'id'),
      category: _readString(map, 'category'),
      style: _readOptionalString(map, 'style'),
      size: _readOptionalString(map, 'size'),
      colorName: _readString(map, 'colorName'),
      colorValue: _readInt(map, 'colorValue'),
      quantity: quantity,
      unitPrice: _readDouble(map, 'unitPrice'),
      notes: _readOptionalString(map, 'notes') ?? '',
      designId: _readOptionalString(map, 'designId'),
    );
  }

  static const int minQuantity = 1;
  static const int maxQuantity = 1000000;

  final String id;
  final String category;
  final String? style;
  final String? size;
  final String colorName;

  /// ARGB value of the product color.
  final int colorValue;
  final int quantity;

  /// Sample starting price per piece in BDT (0 means quote after review).
  final double unitPrice;
  final String notes;

  /// Id of the saved design attached to this line, if any.
  final String? designId;

  bool get hasEstimate => unitPrice > 0;

  double get lineTotal => unitPrice * quantity;

  /// Short description such as "Pullover · Blue · S".
  String get summary {
    final String? styleValue = style;
    final String? sizeValue = size;
    final List<String> parts = <String>[
      ?styleValue,
      colorName,
      ?sizeValue,
    ];
    return parts.join(' · ');
  }

  CartItem copyWith({int? quantity}) {
    return CartItem(
      id: id,
      category: category,
      style: style,
      size: size,
      colorName: colorName,
      colorValue: colorValue,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice,
      notes: notes,
      designId: designId,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'category': category,
      'style': style,
      'size': size,
      'colorName': colorName,
      'colorValue': colorValue,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'notes': notes,
      'designId': designId,
    };
  }

  static String _readString(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is String) return value;
    throw FormatException('Invalid or missing "$key"');
  }

  static String? _readOptionalString(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value == null) return null;
    if (value is String) return value;
    throw FormatException('Invalid "$key"');
  }

  static int _readInt(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is num) return value.toInt();
    throw FormatException('Invalid or missing "$key"');
  }

  static double _readDouble(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is num) return value.toDouble();
    throw FormatException('Invalid or missing "$key"');
  }
}
