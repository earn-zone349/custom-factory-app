import 'package:flutter/material.dart';

/// Describes a product category customers can customize.
@immutable
class ProductCategory {
  const ProductCategory({
    required this.name,
    required this.subtitle,
    required this.icon,
  });

  final String name;
  final String subtitle;
  final IconData icon;

  /// Initial product lineup. Will later be loaded from the database.
  static const List<ProductCategory> defaults = <ProductCategory>[
    ProductCategory(
      name: 'T-Shirt',
      subtitle: 'Custom prints',
      icon: Icons.checkroom_rounded,
    ),
    ProductCategory(
      name: 'Mug',
      subtitle: 'Gifts & branding',
      icon: Icons.coffee_rounded,
    ),
    ProductCategory(
      name: 'Shopping Bag',
      subtitle: 'Brand your bag',
      icon: Icons.shopping_bag_rounded,
    ),
    ProductCategory(
      name: 'Sandal',
      subtitle: 'Your own style',
      icon: Icons.directions_walk_rounded,
    ),
  ];
}
