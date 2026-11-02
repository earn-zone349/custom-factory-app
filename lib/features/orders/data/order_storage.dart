import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/storage/json_file.dart';
import '../models/order.dart';

/// Stores all orders in one JSON file on the device (newest first).
/// Entries this version cannot read are kept untouched when saving.
class OrderStorage {
  OrderStorage({Future<File> Function()? fileProvider})
      : _fileProvider =
            fileProvider ?? (() => JsonFile.inDocuments('orders.json'));

  final Future<File> Function() _fileProvider;

  Future<List<Object?>> _readRaw(File file) async {
    final Object? decoded = await JsonFile.read(file);
    if (decoded == null) return <Object?>[];
    if (decoded is! List<dynamic>) {
      throw const FormatException('Orders file is not valid');
    }
    return List<Object?>.of(decoded);
  }

  /// All readable orders, newest first. Invalid entries are skipped.
  Future<List<Order>> read() async {
    final List<Object?> raw = await _readRaw(await _fileProvider());
    final List<Order> orders = <Order>[];
    for (final Object? entry in raw) {
      if (entry is! Map<String, dynamic>) continue;
      try {
        orders.add(Order.fromMap(entry));
      } on FormatException catch (error) {
        debugPrint('Skipping invalid order: $error');
      }
    }
    return orders;
  }

  /// Changes the status of one order. Returns false if no order has [id].
  /// Throws [FormatException] if the file is unreadable; the file is then
  /// left untouched. Entries this version cannot read are kept as they are.
  Future<bool> updateStatus(String id, OrderStatus status) async {
    final File file = await _fileProvider();
    final List<Object?> raw = await _readRaw(file);
    bool found = false;
    final List<Object?> next = raw.map<Object?>((Object? entry) {
      if (entry is Map<String, dynamic> && entry['id'] == id) {
        found = true;
        return <String, Object?>{...entry, 'status': status.name};
      }
      return entry;
    }).toList();
    if (!found) return false;
    await JsonFile.writeAtomic(file, next);
    return true;
  }

  /// Sets or clears the factory of one order. Returns false if no order has
  /// [id]. Throws [FormatException] if the file is unreadable (the file is
  /// then left untouched). Entries this version cannot read are kept as is.
  Future<bool> assignManufacturer(
    String id,
    String? manufacturerId,
    String? manufacturerName,
  ) async {
    final File file = await _fileProvider();
    final List<Object?> raw = await _readRaw(file);
    bool found = false;
    final List<Object?> next = raw.map<Object?>((Object? entry) {
      if (entry is Map<String, dynamic> && entry['id'] == id) {
        found = true;
        return <String, Object?>{
          ...entry,
          'manufacturerId': manufacturerId,
          'manufacturerName': manufacturerName,
        };
      }
      return entry;
    }).toList();
    if (!found) return false;
    await JsonFile.writeAtomic(file, next);
    return true;
  }

  /// Adds an order at the front. A corrupt file is copied to
  /// "orders.json.corrupt" first, so no earlier order is ever lost.
  Future<void> add(Order order) async {
    final File file = await _fileProvider();
    List<Object?> raw;
    try {
      raw = await _readRaw(file);
    } on FormatException {
      await file.copy('${file.path}.corrupt');
      raw = <Object?>[];
    }
    await JsonFile.writeAtomic(file, <Object?>[order.toMap(), ...raw]);
  }
}
