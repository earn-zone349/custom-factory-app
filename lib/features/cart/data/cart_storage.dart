import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/cart_item.dart';

/// Stores the cart as one JSON file on the device.
/// Writes are atomic (temp file then rename), so a crash never corrupts it.
class CartStorage {
  CartStorage({Future<File> Function()? fileProvider})
      : _fileProvider = fileProvider ?? _defaultFile;

  final Future<File> Function() _fileProvider;

  static Future<File> _defaultFile() async {
    final Directory base = await getApplicationDocumentsDirectory();
    return File('${base.path}/cart.json');
  }

  /// Reads the cart. Invalid lines are skipped; an unreadable file throws.
  Future<List<CartItem>> read() async {
    final File file = await _fileProvider();
    if (!await file.exists()) return <CartItem>[];

    final Object? decoded = jsonDecode(await file.readAsString());
    if (decoded is! List<dynamic>) {
      throw const FormatException('Cart file is not valid');
    }

    final List<CartItem> items = <CartItem>[];
    for (final Object? entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        items.add(CartItem.fromMap(entry));
      } on FormatException catch (error) {
        debugPrint('Skipping invalid cart line: $error');
      }
    }
    return items;
  }

  Future<void> write(List<CartItem> items) async {
    final File target = await _fileProvider();
    final File temp = File('${target.path}.tmp');
    final String json = jsonEncode(
      items.map((CartItem item) => item.toMap()).toList(),
    );
    await temp.writeAsString(json, flush: true);
    await temp.rename(target.path);
  }
}
