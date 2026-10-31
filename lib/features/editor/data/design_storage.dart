import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'design_document.dart';

/// Stores designs as JSON files on the device.
/// Writes are atomic (temp file then rename) so a crash never corrupts a
/// saved design.
class DesignStorage {
  DesignStorage({Future<Directory> Function()? rootProvider})
      : _rootProvider = rootProvider ?? _defaultRoot;

  static final RegExp _validId = RegExp(r'^[A-Za-z0-9_-]+$');

  final Future<Directory> Function() _rootProvider;

  static Future<Directory> _defaultRoot() async {
    final Directory base = await getApplicationDocumentsDirectory();
    return Directory('${base.path}/designs');
  }

  static void _checkId(String id) {
    if (!_validId.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Invalid design id');
    }
  }

  Future<Directory> _ensureRoot() async {
    final Directory root = await _rootProvider();
    if (!await root.exists()) {
      await root.create(recursive: true);
    }
    return root;
  }

  /// Saves [document] and returns its id. Pass [id] to overwrite a design.
  Future<String> save(DesignDocument document, {String? id}) async {
    final String designId =
        id ?? DateTime.now().microsecondsSinceEpoch.toString();
    _checkId(designId);
    final Directory root = await _ensureRoot();
    final File target = File('${root.path}/$designId.json');
    final File temp = File('${target.path}.tmp');
    await temp.writeAsString(document.toJson(), flush: true);
    await temp.rename(target.path);
    return designId;
  }

  Future<DesignDocument> load(String id) async {
    _checkId(id);
    final Directory root = await _ensureRoot();
    final File file = File('${root.path}/$id.json');
    if (!await file.exists()) {
      throw FileSystemException('Design not found', file.path);
    }
    return DesignDocument.fromJson(await file.readAsString());
  }

  Future<void> delete(String id) async {
    _checkId(id);
    final Directory root = await _ensureRoot();
    final File file = File('${root.path}/$id.json');
    if (await file.exists()) {
      await file.delete();
    }
  }

  /// Ids of all saved designs, newest first.
  Future<List<String>> listIds() async {
    final Directory root = await _ensureRoot();
    final List<MapEntry<String, DateTime>> found =
        <MapEntry<String, DateTime>>[];

    await for (final FileSystemEntity entity in root.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final String name = entity.uri.pathSegments.last;
      final String id = name.substring(0, name.length - '.json'.length);
      if (!_validId.hasMatch(id)) continue;
      final FileStat stat = await entity.stat();
      found.add(MapEntry<String, DateTime>(id, stat.modified));
    }

    found.sort(
      (MapEntry<String, DateTime> a, MapEntry<String, DateTime> b) =>
          b.value.compareTo(a.value),
    );
    return found.map((MapEntry<String, DateTime> e) => e.key).toList();
  }
}
