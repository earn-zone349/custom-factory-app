import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../core/storage/json_file.dart';
import '../models/delivery_address.dart';

/// Remembers the last delivery address so the next order is faster.
class AddressStorage {
  AddressStorage({Future<File> Function()? fileProvider})
      : _fileProvider =
            fileProvider ?? (() => JsonFile.inDocuments('address.json'));

  final Future<File> Function() _fileProvider;

  /// The saved address, or null if there is none or it cannot be read.
  Future<DeliveryAddress?> read() async {
    try {
      final Object? decoded = await JsonFile.read(await _fileProvider());
      if (decoded is! Map<String, dynamic>) return null;
      return DeliveryAddress.fromMap(decoded);
    } on FormatException catch (error) {
      debugPrint('Ignoring unreadable saved address: $error');
      return null;
    }
  }

  Future<void> save(DeliveryAddress address) async {
    await JsonFile.writeAtomic(await _fileProvider(), address.toMap());
  }
}
