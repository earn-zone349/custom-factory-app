import 'package:flutter/foundation.dart';

import '../../core/utils/validators.dart';
import '../checkout/data/bd_districts.dart';
import 'data/manufacturer_storage.dart';
import 'models/manufacturer.dart';

/// A change the admin tried to make was refused. The message is meant to be
/// shown to the admin.
class ManufacturerException implements Exception {
  const ManufacturerException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Holds the factory list and keeps it saved on the device.
/// Every change is saved first and applied after, so a failed save never
/// leaves the screen out of sync with the stored list.
class ManufacturerController extends ChangeNotifier {
  ManufacturerController({ManufacturerStorage? storage})
      : _storage = storage ?? ManufacturerStorage();

  final ManufacturerStorage _storage;
  List<Manufacturer> _entries = <Manufacturer>[];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  /// Every factory, including inactive ones.
  List<Manufacturer> get entries =>
      List<Manufacturer>.unmodifiable(_entries);

  /// Factories that can be assigned new orders.
  List<Manufacturer> get activeEntries {
    return List<Manufacturer>.unmodifiable(
      _entries.where((Manufacturer entry) => entry.isActive),
    );
  }

  /// The factory with this id, or null if it does not exist (any more).
  Manufacturer? byId(String id) {
    for (final Manufacturer entry in _entries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> load() async {
    try {
      _entries = await _storage.read();
    } on FormatException catch (error) {
      debugPrint('Saved factories are unreadable: $error');
      try {
        await _storage.backupUnreadable();
      } on Exception catch (backupError) {
        debugPrint('Could not back up the unreadable file: $backupError');
      }
      _entries = <Manufacturer>[];
    } on Exception catch (error) {
      debugPrint('Could not read the factories: $error');
    }
    _isLoaded = true;
    notifyListeners();
  }

  /// A new id for a factory the admin adds.
  static String newId() => 'factory_${DateTime.now().microsecondsSinceEpoch}';

  bool isNameTaken(String name, {String? excludingId}) {
    final String wanted = name.trim().toLowerCase();
    return _entries.any(
      (Manufacturer entry) =>
          entry.id != excludingId && entry.name.trim().toLowerCase() == wanted,
    );
  }

  /// Returns a message describing the first problem, or null if it is valid.
  String? validate(Manufacturer candidate) {
    final String name = candidate.name.trim();
    if (name.length < ManufacturerRules.minNameLength) {
      return 'Enter a name with at least ${ManufacturerRules.minNameLength} characters';
    }
    if (name.length > ManufacturerRules.maxNameLength) {
      return 'The name can have at most ${ManufacturerRules.maxNameLength} characters';
    }
    if (isNameTaken(name, excludingId: candidate.id)) {
      return 'Another factory already uses this name';
    }

    final String contact = candidate.contactPerson.trim();
    if (contact.length < ManufacturerRules.minNameLength ||
        contact.length > ManufacturerRules.maxContactLength) {
      return 'Enter the contact person (${ManufacturerRules.minNameLength} to ${ManufacturerRules.maxContactLength} characters)';
    }

    final String? phoneError = Validators.phone(candidate.phone);
    if (phoneError != null) return phoneError;

    if (!BdDistricts.all.contains(candidate.district)) {
      return 'Select a district';
    }
    if (candidate.notes.trim().length > ManufacturerRules.maxNotesLength) {
      return 'Notes can have at most ${ManufacturerRules.maxNotesLength} characters';
    }
    return _validateCategories(candidate.categories);
  }

  static String? _validateCategories(List<String> values) {
    if (values.isEmpty) {
      return 'Select at least one product this factory can make';
    }
    if (values.length > ManufacturerRules.maxCategories) {
      return 'A factory can have at most ${ManufacturerRules.maxCategories} products';
    }
    final Set<String> seen = <String>{};
    for (final String value in values) {
      final String trimmed = value.trim();
      if (trimmed.isEmpty ||
          trimmed.length > ManufacturerRules.maxCategoryLength) {
        return 'Each product name needs 1 to ${ManufacturerRules.maxCategoryLength} characters';
      }
      if (!seen.add(trimmed.toLowerCase())) {
        return '"$trimmed" is listed twice';
      }
    }
    return null;
  }

  /// Adds a factory, or replaces the one with the same id.
  /// Throws [ManufacturerException] if the change is not allowed.
  Future<void> save(Manufacturer entry) async {
    final Manufacturer cleaned = entry.copyWith(
      name: entry.name.trim(),
      contactPerson: entry.contactPerson.trim(),
      phone: entry.phone.trim(),
      notes: entry.notes.trim(),
    );
    final String? error = validate(cleaned);
    if (error != null) throw ManufacturerException(error);

    final List<Manufacturer> next = List<Manufacturer>.of(_entries);
    final int index =
        next.indexWhere((Manufacturer m) => m.id == cleaned.id);
    if (index >= 0) {
      next[index] = cleaned;
    } else {
      if (next.length >= ManufacturerRules.maxEntries) {
        throw const ManufacturerException(
          'You can have at most ${ManufacturerRules.maxEntries} factories',
        );
      }
      next.add(cleaned);
    }
    await _persist(next);
  }

  /// Turns a factory on or off for new orders.
  Future<void> setActive(String id, {required bool isActive}) async {
    final List<Manufacturer> next = List<Manufacturer>.of(_entries);
    final int index = next.indexWhere((Manufacturer m) => m.id == id);
    if (index < 0) throw const ManufacturerException('Factory not found');
    next[index] = next[index].copyWith(isActive: isActive);
    await _persist(next);
  }

  /// Deletes a factory. Orders already assigned to it keep its name.
  Future<void> delete(String id) async {
    final List<Manufacturer> next = List<Manufacturer>.of(_entries);
    final int index = next.indexWhere((Manufacturer m) => m.id == id);
    if (index < 0) throw const ManufacturerException('Factory not found');
    next.removeAt(index);
    await _persist(next);
  }

  Future<void> _persist(List<Manufacturer> next) async {
    await _storage.write(next);
    _entries = next;
    notifyListeners();
  }
}
