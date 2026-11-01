import 'package:flutter/material.dart';

import '../../customize/models/category_config.dart';
import '../../home/models/product_category.dart';
import 'catalog_icons.dart';

/// Limits for what the admin can enter. Kept in one place so the forms and
/// the controller always agree.
class CatalogRules {
  const CatalogRules._();

  static const int minNameLength = 2;
  static const int maxNameLength = 30;
  static const int maxSubtitleLength = 40;
  static const int maxPrice = 1000000;
  static const int maxListItems = 20;
  static const int maxItemLength = 30;
  static const int maxEntries = 30;
}

/// One product category as managed by the admin: what customers see on the
/// home screen plus the options and price they get when customizing it.
@immutable
class CatalogEntry {
  const CatalogEntry({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.iconKey,
    required this.styles,
    required this.sizes,
    required this.startingPrice,
    this.isActive = true,
    this.isBuiltIn = false,
  });

  /// Parses an entry. Throws [FormatException] for invalid data.
  factory CatalogEntry.fromMap(Map<String, dynamic> map) {
    final double price = _readDouble(map, 'startingPrice');
    if (price < 0 || price > CatalogRules.maxPrice) {
      throw const FormatException('Price is out of range');
    }
    return CatalogEntry(
      id: _readString(map, 'id'),
      name: _readString(map, 'name'),
      subtitle: _readOptionalString(map, 'subtitle'),
      iconKey: _readString(map, 'iconKey'),
      styles: _readStringList(map, 'styles'),
      sizes: _readStringList(map, 'sizes'),
      startingPrice: price,
      isActive: _readBool(map, 'isActive'),
      isBuiltIn: _readBool(map, 'isBuiltIn'),
    );
  }

  /// Stable identity. It never changes, even if the product is renamed.
  final String id;
  final String name;
  final String subtitle;
  final String iconKey;

  /// Suggested styles. Empty means the customer describes the product.
  final List<String> styles;
  final List<String> sizes;

  /// Starting price per piece in BDT (0 means quote after review).
  final double startingPrice;

  /// Hidden products are not shown to customers.
  final bool isActive;

  /// Built-in products can be hidden but not deleted.
  final bool isBuiltIn;

  IconData get icon => CatalogIcons.byKey(iconKey);

  /// The card shown on the home screen.
  ProductCategory toProductCategory() {
    return ProductCategory(name: name, subtitle: subtitle, icon: icon);
  }

  /// The options shown on the customize screen.
  CategoryConfig toConfig() {
    return CategoryConfig(
      name: name,
      styles: styles,
      sizes: sizes,
      startingPrice: startingPrice,
    );
  }

  CatalogEntry copyWith({
    String? name,
    String? subtitle,
    String? iconKey,
    List<String>? styles,
    List<String>? sizes,
    double? startingPrice,
    bool? isActive,
  }) {
    return CatalogEntry(
      id: id,
      name: name ?? this.name,
      subtitle: subtitle ?? this.subtitle,
      iconKey: iconKey ?? this.iconKey,
      styles: styles ?? this.styles,
      sizes: sizes ?? this.sizes,
      startingPrice: startingPrice ?? this.startingPrice,
      isActive: isActive ?? this.isActive,
      isBuiltIn: isBuiltIn,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'subtitle': subtitle,
      'iconKey': iconKey,
      'styles': styles,
      'sizes': sizes,
      'startingPrice': startingPrice,
      'isActive': isActive,
      'isBuiltIn': isBuiltIn,
    };
  }

  /// The products the app ships with, built from the original lists.
  static List<CatalogEntry> get defaults {
    return ProductCategory.defaults.map((ProductCategory category) {
      final CategoryConfig? config = CategoryConfig.byName(category.name);
      return CatalogEntry(
        id: _slug(category.name),
        name: category.name,
        subtitle: category.subtitle,
        iconKey: CatalogIcons.keyFor(category.icon),
        styles: config?.styles ?? const <String>[],
        sizes: config?.sizes ?? const <String>[],
        startingPrice: config?.startingPrice ?? 0,
        isBuiltIn: true,
      );
    }).toList();
  }

  static String _slug(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
  }

  static String _readString(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is String && value.trim().isNotEmpty) return value;
    throw FormatException('Invalid or missing "$key"');
  }

  static String _readOptionalString(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value == null) return '';
    if (value is String) return value;
    throw FormatException('Invalid "$key"');
  }

  static double _readDouble(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is num) return value.toDouble();
    throw FormatException('Invalid or missing "$key"');
  }

  static bool _readBool(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is bool) return value;
    throw FormatException('Invalid or missing "$key"');
  }

  static List<String> _readStringList(Map<String, dynamic> map, String key) {
    final Object? value = map[key];
    if (value is! List<dynamic>) {
      throw FormatException('Invalid or missing "$key"');
    }
    return value.map((Object? item) {
      if (item is String && item.trim().isNotEmpty) return item;
      throw FormatException('Invalid item in "$key"');
    }).toList();
  }
}
