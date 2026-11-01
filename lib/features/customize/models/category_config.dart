import 'package:flutter/material.dart';

/// A selectable color option.
@immutable
class ColorOption {
  const ColorOption({required this.name, required this.value});

  final String name;
  final Color value;
}

/// Customization options available for one product category.
/// Styles, sizes and prices are samples; they will come from the database.
@immutable
class CategoryConfig {
  const CategoryConfig({
    required this.name,
    required this.styles,
    required this.sizes,
    required this.startingPrice,
  });

  final String name;

  /// Suggested styles. Empty means the customer describes the product.
  final List<String> styles;
  final List<String> sizes;

  /// Sample starting price per piece in BDT (0 means quote after review).
  final double startingPrice;

  bool get isCustom => styles.isEmpty;

  static const List<ColorOption> colors = <ColorOption>[
    ColorOption(name: 'White', value: Color(0xFFFFFFFF)),
    ColorOption(name: 'Black', value: Color(0xFF111827)),
    ColorOption(name: 'Red', value: Color(0xFFDC2626)),
    ColorOption(name: 'Blue', value: Color(0xFF2563EB)),
    ColorOption(name: 'Green', value: Color(0xFF16A34A)),
    ColorOption(name: 'Yellow', value: Color(0xFFFACC15)),
    ColorOption(name: 'Navy', value: Color(0xFF1E3A8A)),
    ColorOption(name: 'Sky Blue', value: Color(0xFF38BDF8)),
    ColorOption(name: 'Teal', value: Color(0xFF0D9488)),
    ColorOption(name: 'Lime', value: Color(0xFF84CC16)),
    ColorOption(name: 'Maroon', value: Color(0xFF7F1D1D)),
    ColorOption(name: 'Orange', value: Color(0xFFF97316)),
    ColorOption(name: 'Pink', value: Color(0xFFEC4899)),
    ColorOption(name: 'Purple', value: Color(0xFF7C3AED)),
    ColorOption(name: 'Gray', value: Color(0xFF6B7280)),
    ColorOption(name: 'Light Gray', value: Color(0xFFD1D5DB)),
    ColorOption(name: 'Charcoal', value: Color(0xFF374151)),
    ColorOption(name: 'Beige', value: Color(0xFFE9DCC3)),
    ColorOption(name: 'Brown', value: Color(0xFF92400E)),
    ColorOption(name: 'Cream', value: Color(0xFFFEF3C7)),
    ColorOption(name: 'Mustard', value: Color(0xFFCA8A04)),
    ColorOption(name: 'Coral', value: Color(0xFFFB7185)),
    ColorOption(name: 'Lavender', value: Color(0xFFC4B5FD)),
    ColorOption(name: 'Mint', value: Color(0xFFA7F3D0)),
  ];

  static const List<String> _apparelSizes = <String>[
    'S', 'M', 'L', 'XL', 'XXL',
  ];

  static const List<CategoryConfig> all = <CategoryConfig>[
    CategoryConfig(
      name: 'T-Shirt',
      styles: <String>['Round Neck', 'Polo', 'V-Neck', 'Full Sleeve'],
      sizes: _apparelSizes,
      startingPrice: 350,
    ),
    CategoryConfig(
      name: 'Jersey',
      styles: <String>['Football', 'Cricket', 'Sports', 'Esports'],
      sizes: _apparelSizes,
      startingPrice: 600,
    ),
    CategoryConfig(
      name: 'Hoodie',
      styles: <String>['Pullover', 'Zipper'],
      sizes: _apparelSizes,
      startingPrice: 900,
    ),
    CategoryConfig(
      name: 'Cap',
      styles: <String>['Baseball', 'Snapback', 'Bucket'],
      sizes: <String>['Free size'],
      startingPrice: 250,
    ),
    CategoryConfig(
      name: 'Mug',
      styles: <String>['Ceramic', 'Travel', 'Magic'],
      sizes: <String>['11 oz', '15 oz'],
      startingPrice: 250,
    ),
    CategoryConfig(
      name: 'Shopping Bag',
      styles: <String>['Paper', 'Cloth Tote', 'Non-woven'],
      sizes: <String>['Small', 'Medium', 'Large'],
      startingPrice: 40,
    ),
    CategoryConfig(
      name: 'Sandal',
      styles: <String>['Slide', 'Flip-flop', 'Slipper'],
      sizes: <String>['6', '7', '8', '9', '10', '11'],
      startingPrice: 300,
    ),
    CategoryConfig(
      name: 'Packaging Box',
      styles: <String>['Corrugated', 'Gift Box', 'Food Box'],
      sizes: <String>['Small', 'Medium', 'Large'],
      startingPrice: 60,
    ),
    CategoryConfig(
      name: 'Other',
      styles: <String>[],
      sizes: <String>[],
      startingPrice: 0,
    ),
  ];

  /// Returns the config for a category name, or null if none exists.
  static CategoryConfig? byName(String name) {
    for (final CategoryConfig config in all) {
      if (config.name == name) return config;
    }
    return null;
  }
}
