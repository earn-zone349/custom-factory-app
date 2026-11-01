import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/cart/models/cart_item.dart';
import 'package:custom_factory_app/features/checkout/data/bd_districts.dart';
import 'package:custom_factory_app/features/orders/data/address_storage.dart';
import 'package:custom_factory_app/features/orders/data/order_service.dart';
import 'package:custom_factory_app/features/orders/data/order_storage.dart';
import 'package:custom_factory_app/features/orders/models/delivery_address.dart';
import 'package:custom_factory_app/features/orders/models/order.dart';
import 'package:custom_factory_app/features/orders/models/payment_method.dart';

const DeliveryAddress _address = DeliveryAddress(
  fullName: 'Rahim Uddin',
  phone: '01712345678',
  district: 'Dhaka',
  area: 'Mirpur',
  addressLine: 'House 5, Road 3, Block C',
  landmark: 'Near the mosque',
);

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

Order _order(String id) {
  return Order(
    id: id,
    createdAt: DateTime.utc(2026, 11, 1, 10),
    items: <CartItem>[_item('a'), _item('b', quantity: 3, unitPrice: 0)],
    address: _address,
    paymentMethod: PaymentMethod.cashOnDelivery,
  );
}

void main() {
  group('BdDistricts', () {
    test('lists the 64 districts once each, in alphabetical order', () {
      expect(BdDistricts.all.length, 64);
      expect(BdDistricts.all.toSet().length, 64);
      final List<String> sorted = List<String>.of(BdDistricts.all)..sort();
      expect(BdDistricts.all, orderedEquals(sorted));
      expect(BdDistricts.all, contains('Dhaka'));
    });
  });

  group('DeliveryAddress', () {
    test('survives a map round trip and formats on one line', () {
      final DeliveryAddress restored =
          DeliveryAddress.fromMap(_address.toMap());
      expect(restored.fullName, 'Rahim Uddin');
      expect(
        restored.formatted,
        'House 5, Road 3, Block C, Mirpur, Dhaka (Near Near the mosque)',
      );
    });

    test('rejects missing required fields', () {
      final Map<String, dynamic> map =
          Map<String, dynamic>.of(_address.toMap())..['phone'] = ' ';
      expect(() => DeliveryAddress.fromMap(map), throwsFormatException);
    });
  });

  group('Order', () {
    test('survives a map round trip', () {
      final Order restored = Order.fromMap(_order('CF-1').toMap());

      expect(restored.id, 'CF-1');
      expect(
        restored.createdAt.isAtSameMomentAs(DateTime.utc(2026, 11, 1, 10)),
        isTrue,
      );
      expect(restored.items.length, 2);
      expect(restored.totalPieces, 5);
      expect(restored.estimatedTotal, 200);
      expect(restored.hasUnpricedItems, isTrue);
      expect(restored.status, OrderStatus.placed);
      expect(restored.paymentMethod, PaymentMethod.cashOnDelivery);
    });

    test('rejects an order without items', () {
      final Map<String, dynamic> map =
          Map<String, dynamic>.of(_order('CF-1').toMap())
            ..['items'] = <Object?>[];
      expect(() => Order.fromMap(map), throwsFormatException);
    });
  });

  group('OrderService and storage', () {
    late Directory temp;
    late OrderStorage orders;
    late AddressStorage addresses;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('order_test');
      orders = OrderStorage(
        fileProvider: () async => File('${temp.path}/orders.json'),
      );
      addresses = AddressStorage(
        fileProvider: () async => File('${temp.path}/address.json'),
      );
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    OrderService service() {
      return OrderService(
        orderStorage: orders,
        addressStorage: addresses,
        clock: () => DateTime.utc(2026, 11, 1, 10),
      );
    }

    test('places an order, saves it and remembers the address', () async {
      final Order order = await service().placeOrder(
        items: <CartItem>[_item('a')],
        address: _address,
        paymentMethod: PaymentMethod.cashOnDelivery,
      );

      expect(order.id, startsWith('CF-'));
      expect((await orders.read()).single.id, order.id);
      expect((await addresses.read())?.district, 'Dhaka');
    });

    test('refuses an empty cart and unavailable payment methods', () async {
      await expectLater(
        service().placeOrder(
          items: <CartItem>[],
          address: _address,
          paymentMethod: PaymentMethod.cashOnDelivery,
        ),
        throwsArgumentError,
      );
      await expectLater(
        service().placeOrder(
          items: <CartItem>[_item('a')],
          address: _address,
          paymentMethod: PaymentMethod.bkash,
        ),
        throwsArgumentError,
      );
      expect(await orders.read(), isEmpty);
    });

    test('newest order comes first', () async {
      await orders.add(_order('CF-OLD'));
      await orders.add(_order('CF-NEW'));

      final List<String> ids =
          (await orders.read()).map((Order o) => o.id).toList();
      expect(ids, <String>['CF-NEW', 'CF-OLD']);
    });

    test('a corrupt file is backed up and never loses data silently', () async {
      final File file = File('${temp.path}/orders.json');
      await file.writeAsString('not json');

      await orders.add(_order('CF-1'));

      expect((await orders.read()).length, 1);
      expect(await File('${temp.path}/orders.json.corrupt').exists(), isTrue);
    });

    test('keeps entries this version cannot read', () async {
      final File file = File('${temp.path}/orders.json');
      await file.writeAsString(
        jsonEncode(<Object?>[
          <String, Object?>{'id': 'future-format'},
        ]),
      );

      await orders.add(_order('CF-1'));

      final List<dynamic> raw =
          jsonDecode(await file.readAsString()) as List<dynamic>;
      expect(raw.length, 2);
      expect((await orders.read()).length, 1);
    });
  });
}
