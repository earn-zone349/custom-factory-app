import 'package:flutter/material.dart';

/// An icon the admin can choose for a product.
@immutable
class CatalogIconOption {
  const CatalogIconOption({required this.key, required this.icon});

  /// Stable name saved in the catalog file.
  final String key;
  final IconData icon;
}

/// The icons available for products.
class CatalogIcons {
  const CatalogIcons._();

  static const String fallbackKey = 'box';

  static const List<CatalogIconOption> options = <CatalogIconOption>[
    CatalogIconOption(key: 'tshirt', icon: Icons.checkroom_rounded),
    CatalogIconOption(key: 'jersey', icon: Icons.sports_soccer_rounded),
    CatalogIconOption(key: 'hoodie', icon: Icons.dry_cleaning_rounded),
    CatalogIconOption(key: 'cap', icon: Icons.sports_baseball_rounded),
    CatalogIconOption(key: 'mug', icon: Icons.coffee_rounded),
    CatalogIconOption(key: 'bag', icon: Icons.shopping_bag_rounded),
    CatalogIconOption(key: 'sandal', icon: Icons.directions_walk_rounded),
    CatalogIconOption(key: 'box', icon: Icons.inventory_2_rounded),
    CatalogIconOption(key: 'sparkle', icon: Icons.auto_awesome_rounded),
    CatalogIconOption(key: 'bottle', icon: Icons.local_drink_rounded),
    CatalogIconOption(key: 'phone', icon: Icons.phone_android_rounded),
    CatalogIconOption(key: 'book', icon: Icons.menu_book_rounded),
    CatalogIconOption(key: 'gift', icon: Icons.card_giftcard_rounded),
    CatalogIconOption(key: 'watch', icon: Icons.watch_rounded),
    CatalogIconOption(key: 'print', icon: Icons.print_rounded),
    CatalogIconOption(key: 'star', icon: Icons.star_rounded),
  ];

  /// The icon for [key]. Unknown keys give the box icon.
  static IconData byKey(String key) {
    for (final CatalogIconOption option in options) {
      if (option.key == key) return option.icon;
    }
    return Icons.inventory_2_rounded;
  }

  /// The key of [icon]. Unknown icons give the fallback key.
  static String keyFor(IconData icon) {
    for (final CatalogIconOption option in options) {
      if (option.icon.codePoint == icon.codePoint &&
          option.icon.fontFamily == icon.fontFamily) {
        return option.key;
      }
    }
    return fallbackKey;
  }
}
