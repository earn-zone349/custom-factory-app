import 'dart:io';

import '../../../core/storage/json_file.dart';
import '../models/manufacturer.dart';

/// Stores the factory list as one JSON file on the device.
/// A missing file means "no factories yet".
class ManufacturerStorage {
  ManufacturerStorage({Future<File> Function()? fileProvider})
      : _fileProvider =
            fileProvider ?? (() => JsonFile.inDocuments('manufacturers.json'));

  final Future<File> Function() _fileProvider;

  /// The saved factories (empty if nothing was saved yet).
  /// Throws [FormatException] if the file cannot be read.
  Future<List<Manufacturer>> read() async {
    final Object? decoded = await JsonFile.read(await _fileProvider());
    if (decoded == null) return <Manufacturer>[];
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Factories file is not valid');
    }
    final Object? raw = decoded['entries'];
    if (raw is! List<dynamic>) {
      throw const FormatException('Factories file has no list');
    }
    return raw.map((Object? entry) {
      if (entry is! Map<String, dynamic>) {
        throw const FormatException('Invalid factory entry');
      }
      return Manufacturer.fromMap(entry);
    }).toList();
  }

  Future<void> write(List<Manufacturer> entries) async {
    await JsonFile.writeAtomic(await _fileProvider(), <String, Object?>{
      'version': 1,
      'entries': entries.map((Manufacturer m) => m.toMap()).toList(),
    });
  }

  /// Copies an unreadable file aside so nothing is lost silently.
  Future<void> backupUnreadable() async {
    final File file = await _fileProvider();
    if (await file.exists()) await file.copy('${file.path}.corrupt');
  }
}
