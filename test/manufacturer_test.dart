import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/cart/models/cart_item.dart';
import 'package:custom_factory_app/features/manufacturers/data/manufacturer_storage.dart';
import 'package:custom_factory_app/features/manufacturers/manufacturer_controller.dart';
import 'package:custom_factory_app/features/manufacturers/models/manufacturer.dart';
import 'package:custom_factory_app/features/orders/data/order_service.dart';
import 'package:custom_factory_app/features/orders/data/order_storage.dart';
import 'package:custom_factory_app/features/orders/models/delivery_address.dart';
import 'package:custom_factory_app/features/orders/models/order.dart';
import 'package:custom_factory_app/features/orders/models/payment_method.dart';

Manufacturer _factory({
  String id = 'f1',
  String name = 'Dhaka Print House',
  List<String> categories = const <String>['Mug', 'T-Shirt'],
  bool isActive = true,
}) {
  return Manufacturer(
    id: id,
    name: name,
    contactPerson: 'Karim',
    phone: '01712345678',
    district: 'Dhaka',
    categories: categories,
    isActive: isActive,
  );
}

Order _order(
  String id, {
  OrderStatus status = OrderStatus.placed,
  List<String> categories = const <String>['Mug'],
}) {
  return Order(
    id: id,
    createdAt: DateTime.utc(2026, 11, 1, 10),
    items: <CartItem>[
      for (int i = 0; i < categories.length; i++)
        CartItem(
          id: 'item_$i',
          category: categories[i],
          colorName: 'Red',
          colorValue: 0xFFDC2626,
          quantity: 2,
          unitPrice: 100,
        ),
    ],
    address: const DeliveryAddress(
      fullName: 'Rahim Uddin',
      phone: '01712345678',
      district: 'Dhaka',
      area: 'Mirpur',
      addressLine: 'House 5, Road 3, Block C',
    ),
    paymentMethod: PaymentMethod.cashOnDelivery,
    status: status,
  );
}

void main() {
  group('Manufacturer', () {
    test('survives a map round trip', () {
      final Manufacturer restored =
          Manufacturer.fromMap(_factory().toMap());

      expect(restored.name, 'Dhaka Print House');
      expect(restored.categories, <String>['Mug', 'T-Shirt']);
      expect(restored.isActive, isTrue);
    });

    test('missingFor ignores letter case and lists what is missing', () {
      final Manufacturer factory = _factory();

      expect(factory.missingFor(<String>['mug', 'T-SHIRT']), isEmpty);
      expect(factory.missingFor(<String>['Mug', 'Sandal']), <String>['Sandal']);
    });
  });

  group('ManufacturerController', () {
    late Directory temp;
    late File file;
    late ManufacturerStorage storage;
    late ManufacturerController controller;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('factory_test');
      file = File('${temp.path}/manufacturers.json');
      storage = ManufacturerStorage(fileProvider: () async => file);
      controller = ManufacturerController(storage: storage);
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('starts empty', () async {
      await controller.load();

      expect(controller.isLoaded, isTrue);
      expect(controller.entries, isEmpty);
    });

    test('saves a factory and keeps it after a restart', () async {
      await controller.save(_factory());

      final ManufacturerController reopened =
          ManufacturerController(storage: storage);
      await reopened.load();

      expect(reopened.entries.single.name, 'Dhaka Print House');
      expect(reopened.byId('f1')?.phone, '01712345678');
    });

    test('rejects a duplicate name, ignoring letter case', () async {
      await controller.save(_factory());

      await expectLater(
        controller.save(_factory(id: 'f2', name: 'dhaka print house')),
        throwsA(isA<ManufacturerException>()),
      );
    });

    test('rejects invalid values', () async {
      final List<Manufacturer> invalid = <Manufacturer>[
        _factory(name: 'A'),
        _factory().copyWith(phone: '12345'),
        _factory().copyWith(district: 'Atlantis'),
        _factory().copyWith(contactPerson: ' '),
        _factory(categories: const <String>[]),
        _factory(categories: const <String>['Mug', 'mug']),
      ];

      for (final Manufacturer candidate in invalid) {
        await expectLater(
          controller.save(candidate),
          throwsA(isA<ManufacturerException>()),
        );
      }
      expect(controller.entries, isEmpty);
    });

    test('can switch a factory off and delete it', () async {
      await controller.save(_factory());

      await controller.setActive('f1', isActive: false);
      expect(controller.activeEntries, isEmpty);

      await controller.delete('f1');
      expect(controller.entries, isEmpty);
    });

    test('an unreadable file is backed up and the list starts empty', () async {
      await file.writeAsString('not json');

      await controller.load();

      expect(controller.entries, isEmpty);
      expect(await File('${file.path}.corrupt').exists(), isTrue);
    });
  });

  group('Assigning a factory to an order', () {
    late Directory temp;
    late OrderStorage storage;
    late OrderService service;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('assign_test');
      storage = OrderStorage(
        fileProvider: () async => File('${temp.path}/orders.json'),
      );
      service = OrderService(orderStorage: storage);
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('the order keeps its factory when saved and read back', () async {
      await storage.add(_order('CF-1'));
      await service.assignManufacturer('CF-1', _factory());

      final Order saved = (await service.findOrder('CF-1'))!;
      expect(saved.manufacturerId, 'f1');
      expect(saved.manufacturerName, 'Dhaka Print House');

      final Order restored = Order.fromMap(saved.toMap());
      expect(restored.manufacturerName, 'Dhaka Print House');
    });

    test('an old order without a factory still loads', () async {
      await storage.add(_order('CF-1'));

      final Order order = (await service.findOrder('CF-1'))!;
      expect(order.manufacturerId, isNull);
      expect(order.manufacturerName, isNull);
    });

    test('refuses a factory that does not make every product', () async {
      await storage.add(_order('CF-1', categories: const <String>['Mug', 'Bag']));

      await expectLater(
        service.assignManufacturer('CF-1', _factory()),
        throwsStateError,
      );
      expect((await service.findOrder('CF-1'))!.manufacturerId, isNull);
    });

    test('refuses an inactive factory', () async {
      await storage.add(_order('CF-1'));

      await expectLater(
        service.assignManufacturer('CF-1', _factory(isActive: false)),
        throwsStateError,
      );
    });

    test('the factory can be changed or removed before production', () async {
      await storage.add(_order('CF-1'));
      await service.assignManufacturer('CF-1', _factory());
      await service.assignManufacturer(
        'CF-1',
        _factory(id: 'f2', name: 'Second Factory'),
      );
      expect((await service.findOrder('CF-1'))!.manufacturerId, 'f2');

      await service.assignManufacturer('CF-1', null);
      expect((await service.findOrder('CF-1'))!.manufacturerId, isNull);
    });

    test('the factory cannot change once production has started', () async {
      await storage.add(_order('CF-1', status: OrderStatus.inProduction));

      await expectLater(
        service.assignManufacturer('CF-1', _factory()),
        throwsStateError,
      );
    });

    test('production cannot start without a factory', () async {
      await storage.add(_order('CF-1'));
      await service.changeStatus('CF-1', OrderStatus.confirmed);

      await expectLater(
        service.changeStatus('CF-1', OrderStatus.inProduction),
        throwsStateError,
      );

      await service.assignManufacturer('CF-1', _factory());
      final Order started =
          await service.changeStatus('CF-1', OrderStatus.inProduction);
      expect(started.status, OrderStatus.inProduction);
    });

    test('refuses an unknown order', () async {
      await expectLater(
        service.assignManufacturer('missing', _factory()),
        throwsStateError,
      );
    });
  });
}
