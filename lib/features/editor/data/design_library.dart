import 'package:flutter/foundation.dart';

import 'design_document.dart';
import 'design_storage.dart';

/// A design saved on this device together with its id.
@immutable
class SavedDesign {
  const SavedDesign({required this.id, required this.document});

  final String id;
  final DesignDocument document;

  /// Creation time, derived from the id (a microsecond timestamp).
  DateTime? get createdAt {
    final int? micros = int.tryParse(id);
    if (micros == null) return null;
    return DateTime.fromMicrosecondsSinceEpoch(micros);
  }
}

/// Reads and deletes the saved designs shown in "My Designs".
class DesignLibrary {
  DesignLibrary({DesignStorage? storage})
      : _storage = storage ?? DesignStorage();

  final DesignStorage _storage;

  /// All readable designs, newest first. Unreadable files are skipped.
  Future<List<SavedDesign>> loadAll() async {
    final List<String> ids = await _storage.listIds();
    final List<SavedDesign> result = <SavedDesign>[];
    for (final String id in ids) {
      try {
        result.add(SavedDesign(id: id, document: await _storage.load(id)));
      } on Exception catch (error) {
        debugPrint('Skipping unreadable design $id: $error');
      }
    }
    return result;
  }

  Future<void> delete(String id) => _storage.delete(id);
}
