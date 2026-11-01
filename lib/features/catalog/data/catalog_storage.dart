import 'dart:io';

import '../../../core/storage/json_file.dart';
import '../models/catalog_entry.dart';

/// Stores the admin-managed catalog as one JSON file on the device.
/// A missing file means "use the built-in defaults".
class CatalogStorage {
  CatalogStorage({Future<File> Function()? fileProvider})
      : _fileProvider =
            fileProvider ?? (() => JsonFile.inDocuments('catalog.json'));

  final Future<File> Function() _fileProvider;

  /// The saved catalog, or null if nothing was saved yet.
  /// Throws [FormatException] if the file cannot be read.
  Future<List<CatalogEntry>?> read() async {
    final Object? decoded = await JsonFile.read(await _fileProvider());
    if (decoded == null) return null;
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Catalog file is not valid');
    }
    final Object? raw = decoded['entries'];
    if (raw is! List<dynamic> || raw.isEmpty) {
      throw const FormatException('Catalog has no entries');
    }
    return raw.map((Object? entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid catalog entry');
      }
      return CatalogEntry.fromMap(entry);
    }).toList();
  }

  Future<void> write(List<CatalogEntry> entries) async {
    await JsonFile.writeAtomic(await _fileProvider(), <String, Object?>{
      'version': 1,
      'entries': entries.map((CatalogEntry e) => e.toMap()).toList(),
    });
  }

  /// Deletes the saved catalog so the defaults apply again.
  Future<void> reset() async {
    final File file = await _fileProvider();
    if (await file.exists()) await file.delete();
  }

  /// Copies an unreadable file aside so nothing is lost silently.
  Future<void> backupUnreadable() async {
    final File file = await _fileProvider();
    if (await file.exists()) await file.copy('${file.path}.corrupt');
  }
}
