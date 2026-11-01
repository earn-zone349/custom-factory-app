import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/cart/cart_controller.dart';
import 'package:custom_factory_app/features/cart/data/cart_storage.dart';
import 'package:custom_factory_app/features/cart/models/cart_item.dart';

CartItem _item(String id, {int quantity = 2, double unitPrice = 100}) {
  return CartItem(
    id: id,
    category: 'Mug',
    style: 'Ceramic',
    size: '11 oz',
    colorName: 'Red',
    colorValue: 0xFFDC2626,
    quantity: quantity,
    unitPrice: unitPrice,
  );
}

void main() {
  late Directory temp;
  late File cartFile;
  late CartStorage storage;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('cart_test');
    cartFile = File('${temp.path}/cart.json');
    storage = CartStorage(fileProvider: () async => cartFile);
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  group('CartController', () {
    test('adds items and computes totals', () async {
      final CartController cart = CartController(storage: storage);
      await cart.add(_item('a'));
      await cart.add(_item('b', quantity: 3, unitPrice: 0));

      expect(cart.itemCount, 2);
      expect(cart.totalPieces, 5);
      expect(cart.estimatedTotal, 200);
      expect(cart.hasUnpricedItems, isTrue);
    });

    test('keeps the cart after a restart', () async {
      await CartController(storage: storage).add(_item('a'));

      final CartController reopened = CartController(storage: storage);
      await reopened.load();

      expect(reopened.itemCount, 1);
      expect(reopened.items.first.id, 'a');
    });

    test('keeps quantity within limits', () async {
      final CartController cart = CartController(storage: storage);
      await cart.add(_item('a'));

      await cart.setQuantity('a', 0);
      expect(cart.items.first.quantity, CartItem.minQuantity);

      await cart.setQuantity('a', 99999999);
      expect(cart.items.first.quantity, CartItem.maxQuantity);
    });

    test('restore puts a removed item back in its place', () async {
      final CartController cart = CartController(storage: storage);
      await cart.add(_item('a'));
      await cart.add(_item('b'));
      await cart.add(_item('c'));

      final CartItem removed = cart.items[1];
      await cart.remove('b');
      expect(cart.items.length, 2);

      await cart.restore(removed, 1);
      expect(
        cart.items.map((CartItem i) => i.id).toList(),
        <String>['a', 'b', 'c'],
      );
    });

    test('refuses to add more than the maximum lines', () async {
      final CartController cart = CartController(storage: storage);
      for (int i = 0; i < CartController.maxLines; i++) {
        expect(await cart.add(_item('item_$i')), isTrue);
      }
      expect(await cart.add(_item('extra')), isFalse);
      expect(cart.itemCount, CartController.maxLines);
    });

    test('a corrupt cart file gives an empty cart', () async {
      await cartFile.writeAsString('not json');

      final CartController cart = CartController(storage: storage);
      await cart.load();

      expect(cart.isLoaded, isTrue);
      expect(cart.items, isEmpty);
    });

    test('skips invalid lines but keeps valid ones', () async {
      await cartFile.writeAsString(
        jsonEncode(<Object?>[
          _item('good').toMap(),
          <String, Object?>{'id': 'bad', 'quantity': 0},
        ]),
      );

      final CartController cart = CartController(storage: storage);
      await cart.load();

      expect(cart.items.map((CartItem i) => i.id).toList(), <String>['good']);
    });
  });

  group('CartItem', () {
    test('survives a map round trip', () {
      final CartItem restored = CartItem.fromMap(_item('a').toMap());
      expect(restored.category, 'Mug');
      expect(restored.summary, 'Ceramic · Red · 11 oz');
      expect(restored.lineTotal, 200);
    });

    test('rejects an out of range quantity', () {
      final Map<String, dynamic> map =
          Map<String, dynamic>.of(_item('a').toMap())..['quantity'] = 0;
      expect(() => CartItem.fromMap(map), throwsFormatException);
    });
  });
}
