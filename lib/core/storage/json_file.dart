import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Small helpers for storing JSON files safely on the device.
class JsonFile {
  const JsonFile._();

  /// A file inside the app's private documents folder.
  static Future<File> inDocuments(String name) async {
    final Directory base = await getApplicationDocumentsDirectory();
    return File('${base.path}/$name');
  }

  /// Reads and decodes a file. Returns null if it does not exist.
  /// Throws [FormatException] if the content is not valid JSON.
  static Future<Object?> read(File file) async {
    if (!await file.exists()) return null;
    return jsonDecode(await file.readAsString());
  }

  /// Writes atomically (temp file, then rename) so a crash cannot corrupt it.
  static Future<void> writeAtomic(File target, Object? data) async {
    final File temp = File('${target.path}.tmp');
    await temp.writeAsString(jsonEncode(data), flush: true);
    await temp.rename(target.path);
  }
}
