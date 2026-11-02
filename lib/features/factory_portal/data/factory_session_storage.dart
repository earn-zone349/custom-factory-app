import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/storage/json_file.dart';

/// Remembers which factory this phone is using the factory panel as.
/// TEMPORARY: replaced by real factory accounts when login is added.
class FactorySessionStorage {
  FactorySessionStorage({Future<File> Function()? fileProvider})
      : _fileProvider = fileProvider ??
            (() => JsonFile.inDocuments('factory_session.json'));

  final Future<File> Function() _fileProvider;

  /// The saved factory id, or null if none is saved or it cannot be read.
  Future<String?> readFactoryId() async {
    try {
      final Object? decoded = await JsonFile.read(await _fileProvider());
      if (decoded is Map<String, dynamic>) {
        final Object? id = decoded['factoryId'];
        if (id is String && id.isNotEmpty) return id;
      }
    } on FormatException catch (error) {
      debugPrint('Ignoring unreadable factory session: $error');
    }
    return null;
  }

  /// Saves the chosen factory, or clears it when [id] is null.
  Future<void> saveFactoryId(String? id) async {
    await JsonFile.writeAtomic(
      await _fileProvider(),
      <String, Object?>{'factoryId': id},
    );
  }
}
