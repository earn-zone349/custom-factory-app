import 'package:flutter/foundation.dart';

import '../customize/models/category_config.dart';
import '../home/models/product_category.dart';
import 'data/catalog_storage.dart';
import 'models/catalog_entry.dart';

/// A change the admin tried to make was refused. The message is meant to be
/// shown to the admin.
class CatalogException implements Exception {
  const CatalogException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Holds the product catalog and keeps it saved on the device.
/// Every change is saved first and applied after, so a failed save never
/// leaves the screen out of sync with the stored catalog.
class CatalogController extends ChangeNotifier {
  CatalogController({CatalogStorage? storage})
      : _storage = storage ?? CatalogStorage();

  final CatalogStorage _storage;
  List<CatalogEntry> _entries = CatalogEntry.defaults;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Every product, including hidden ones.
  List<CatalogEntry> get entries => List<CatalogEntry>.unmodifiable(_entries);

  /// Products customers can see.
  List<CatalogEntry> get activeEntries {
    return List<CatalogEntry>.unmodifiable(
      _entries.where((CatalogEntry entry) => entry.isActive),
    );
  }

  /// The home screen cards for the visible products.
  List<ProductCategory> get activeCategories {
    return activeEntries
        .map((CatalogEntry entry) => entry.toProductCategory())
        .toList();
  }

  /// The customize options for a visible product, or null if there is none.
  CategoryConfig? configFor(String name) {
    for (final CatalogEntry entry in _entries) {
      if (entry.isActive && entry.name == name) return entry.toConfig();
    }
    return null;
  }

  /// Loads the saved catalog. Until then (and if nothing was saved) the
  /// built-in defaults are used.
  Future<void> load() async {
    try {
      final List<CatalogEntry>? saved = await _storage.read();
      if (saved != null) {
        if (saved.any((CatalogEntry entry) => entry.isActive)) {
          _entries = saved;
        } else {
          debugPrint('Saved catalog has no visible product; using defaults');
        }
      }
    } on FormatException catch (error) {
      debugPrint('Saved catalog is unreadable, using defaults: $error');
      try {
        await _storage.backupUnreadable();
      } on Exception catch (backupError) {
        debugPrint('Could not back up the unreadable catalog: $backupError');
      }
    } on Exception catch (error) {
      debugPrint('Could not read the catalog: $error');
    }
    _isLoaded = true;
    notifyListeners();
  }

  /// A new id for a product the admin adds.
  static String newId() => 'custom_${DateTime.now().microsecondsSinceEpoch}';

  bool isNameTaken(String name, {String? excludingId}) {
    final String wanted = name.trim().toLowerCase();
    return _entries.any(
      (CatalogEntry entry) =>
          entry.id != excludingId && entry.name.trim().toLowerCase() == wanted,
    );
  }

  /// Returns a message describing the first problem, or null if it is valid.
  String? validate(CatalogEntry candidate) {
    final String name = candidate.name.trim();
    if (name.length < CatalogRules.minNameLength) {
      return 'Enter a name with at least ${CatalogRules.minNameLength} characters';
    }
    if (name.length > CatalogRules.maxNameLength) {
      return 'The name can have at most ${CatalogRules.maxNameLength} characters';
    }
    if (isNameTaken(name, excludingId: candidate.id)) {
      return 'Another product already uses this name';
    }
    if (candidate.subtitle.trim().length > CatalogRules.maxSubtitleLength) {
      return 'The description can have at most ${CatalogRules.maxSubtitleLength} characters';
    }
    if (candidate.startingPrice < 0 ||
        candidate.startingPrice > CatalogRules.maxPrice) {
      return 'The price must be between 0 and ${CatalogRules.maxPrice}';
    }
    return _validateList('Styles', candidate.styles) ??
        _validateList('Sizes', candidate.sizes);
  }

  static String? _validateList(String label, List<String> values) {
    if (values.length > CatalogRules.maxListItems) {
      return '$label can have at most ${CatalogRules.maxListItems} items';
    }
    final Set<String> seen = <String>{};
    for (final String value in values) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty || trimmed.length > CatalogRules.maxItemLength) {
        return '$label: each item needs 1 to ${CatalogRules.maxItemLength} characters';
      }
      if (!seen.add(trimmed.toLowerCase())) {
        return '$label: "$trimmed" is listed twice';
      }
    }
    return null;
  }

  /// Adds a product, or replaces the one with the same id.
  /// Throws [CatalogException] if the change is not allowed.
  Future<void> save(CatalogEntry entry) async {
    final CatalogEntry cleaned = entry.copyWith(
      name: entry.name.trim(),
      subtitle: entry.subtitle.trim(),
    );
    final String? error = validate(cleaned);
    if (error != null) throw CatalogException(error);

    final List<CatalogEntry> next = List<CatalogEntry>.of(_entries);
    final int index =
        next.indexWhere((CatalogEntry e) => e.id == cleaned.id);
    if (index >= 0) {
      next[index] = cleaned;
    } else {
      if (next.length >= CatalogRules.maxEntries) {
        throw const CatalogException(
          'You can have at most ${CatalogRules.maxEntries} products',
        );
      }
      next.add(cleaned);
    }
    _requireVisibleProduct(next);
    await _persist(next);
  }

  /// Shows or hides a product for customers.
  Future<void> setActive(String id, {required bool isActive}) async {
    final List<CatalogEntry> next = List<CatalogEntry>.of(_entries);
    final int index = next.indexWhere((CatalogEntry e) => e.id == id);
    if (index < 0) throw const CatalogException('Product not found');
    next[index] = next[index].copyWith(isActive: isActive);
    _requireVisibleProduct(next);
    await _persist(next);
  }

  /// Deletes a product the admin added. Built-in products can only be hidden.
  Future<void> delete(String id) async {
    final List<CatalogEntry> next = List<CatalogEntry>.of(_entries);
    final int index = next.indexWhere((CatalogEntry e) => e.id == id);
    if (index < 0) throw const CatalogException('Product not found');
    if (next[index].isBuiltIn) {
      throw const CatalogException('Built-in products can only be hidden');
    }
    next.removeAt(index);
    _requireVisibleProduct(next);
    await _persist(next);
  }

  /// Restores the built-in products, prices and options.
  Future<void> resetToDefaults() async {
    await _storage.reset();
    _entries = CatalogEntry.defaults;
    notifyListeners();
  }

  static void _requireVisibleProduct(List<CatalogEntry> entries) {
    if (!entries.any((CatalogEntry entry) => entry.isActive)) {
      throw const CatalogException('At least one product must stay visible');
    }
  }

  Future<void> _persist(List<CatalogEntry> next) async {
    await _storage.write(next);
    _entries = next;
    notifyListeners();
  }
}
