import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/storage/json_file.dart';
import '../models/order_note.dart';

/// Stores all notes in one JSON file on the device, in the order they were
/// written. Entries this version cannot read are kept untouched when saving.
class NoteStorage {
  NoteStorage({Future<File> Function()? fileProvider})
      : _fileProvider =
            fileProvider ?? (() => JsonFile.inDocuments('order_notes.json'));

  final Future<File> Function() _fileProvider;

  Future<List<Object?>> _readRaw(File file) async {
    final Object? decoded = await JsonFile.read(file);
    if (decoded == null) return <Object?>[];
    if (decoded is! List<dynamic>) {
      throw const FormatException('Notes file is not valid');
    }
    return List<Object?>.of(decoded);
  }

  /// All readable notes, oldest first. Invalid entries are skipped.
  /// Throws [FormatException] if the whole file is unreadable.
  Future<List<OrderNote>> read() async {
    final List<Object?> raw = await _readRaw(await _fileProvider());
    final List<OrderNote> notes = <OrderNote>[];
    for (final Object? entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        notes.add(OrderNote.fromMap(entry));
      } on FormatException catch (error) {
        debugPrint('Skipping invalid note: $error');
      }
    }
    return notes;
  }

  /// Adds a note at the end. A corrupt file is copied to
  /// "order_notes.json.corrupt" first, so no earlier note is lost silently.
  Future<void> add(OrderNote note) async {
    final File file = await _fileProvider();
    List<Object?> raw;
    try {
      raw = await _readRaw(file);
    } on FormatException {
      await file.copy('${file.path}.corrupt');
      raw = <Object?>[];
    }
    await JsonFile.writeAtomic(file, <Object?>[...raw, note.toMap()]);
  }

  /// Marks a note as resolved. Returns false if no note has [id].
  /// Throws [FormatException] if the file is unreadable (it is then left
  /// untouched). Entries this version cannot read are kept as they are.
  Future<bool> markResolved(String id, DateTime when) async {
    final File file = await _fileProvider();
    final List<Object?> raw = await _readRaw(file);
    bool found = false;
    final List<Object?> next = raw.map<Object?>((Object? entry) {
      if (entry is Map<String, dynamic> && entry['id'] == id) {
        found = true;
        return <String, Object?>{
          ...entry,
          'isResolved': true,
          'resolvedAt': when.toUtc().toIso8601String(),
        };
      }
      return entry;
    }).toList();
    if (!found) return false;
    await JsonFile.writeAtomic(file, next);
    return true;
  }
}
