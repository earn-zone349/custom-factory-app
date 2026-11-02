import 'package:flutter/foundation.dart';

/// Limits for what the admin can enter. Kept in one place so the forms and
/// the controller always agree.
class ManufacturerRules {
  const ManufacturerRules._();

  static const int minNameLength = 2;
  static const int maxNameLength = 40;
  static const int maxContactLength = 40;
  static const int maxNotesLength = 200;
  static const int maxCategories = 30;
  static const int maxCategoryLength = 30;
  static const int maxEntries = 50;
}

/// A factory that produces orders. (Named Manufacturer in code.)
@immutable
class Manufacturer {
  const Manufacturer({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.district,
    required this.categories,
    this.notes = '',
    this.isActive = true,
  });

  /// Parses a factory. Throws [FormatException] for invalid data.
  factory Manufacturer.fromMap(Map<String, dynamic> map) {
    return Manufacturer(
      id: _readString(map, 'id'),
      name: _readString(map, 'name'),
      contactPerson: _readString(map, 'contactPerson'),
      phone: _readString(map, 'phone'),
      district: _readString(map, 'district'),
      categories: _readStringList(map, 'categories'),
      notes: _readOptionalString(map, 'notes'),
      isActive: _readBool(map, 'isActive'),
    );
  }

  /// Stable identity. It never changes, even if the factory is renamed.
  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final String district;

  /// Names of the products this factory can make.
  final List<String> categories;
  final String notes;

  /// Inactive factories cannot be assigned new orders.
  final bool isActive;

  /// The products in [required] that this factory does not make.
  /// Names are compared ignoring letter case.
  List<String> missingFor(Iterable<String> required) {
    final Set<String> offered =
        categories.map((String c) => c.trim().toLowerCase()).toSet();
    return required
        .where((String name) => !offered.contains(name.trim().toLowerCase()))
        .toList();
  }

  Manufacturer copyWith({
    String? name,
    String? contactPerson,
    String? phone,
    String? district,
    List<String>? categories,
    String? notes,
    bool? isActive,
  }) {
    return Manufacturer(
      id: id,
      name: name ?? this.name,
      contactPerson: contactPerson ?? this.contactPerson,
      phone: phone ?? this.phone,
      district: district ?? this.district,
      categories: categories ?? this.categories,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
    );
  }

  Map<String, Object?> toMap() {
    return <String, Object?>{
      'id': id,
      'name': name,
      'contactPerson': contactPerson,
      'phone': phone,
      'district': district,
      'categories': categories,
      'notes': notes,
      'isActive': isActive,
    };
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
