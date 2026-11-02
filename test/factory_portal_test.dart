import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/cart/models/cart_item.dart';
import 'package:custom_factory_app/features/factory_portal/data/factory_session_storage.dart';
import 'package:custom_factory_app/features/factory_portal/models/factory_order_filter.dart';
import 'package:custom_factory_app/features/orders/data/order_service.dart';
import 'package:custom_factory_app/features/orders/data/order_storage.dart';
import 'package:custom_factory_app/features/orders/models/delivery_address.dart';
import 'package:custom_factory_app/features/orders/models/order.dart';
import 'package:custom_factory_app/features/orders/models/payment_method.dart';

Order _order(
  String id, {
  OrderStatus status = OrderStatus.confirmed,
  String? factoryId = 'f1',
}) {
  return Order(
    id: id,
    createdAt: DateTime.utc(2026, 11, 1, 10),
    items: const <CartItem>[
      CartItem(
        id: 'a',
        category: 'Mug',
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
    manufacturerId: factoryId,
    manufacturerName: factoryId == null ? null : 'Alpha',
  );
}

void main() {
  group('Factory visibility and moves', () {
    test('a factory sees its own confirmed orders only', () {
      expect(OrderService.isVisibleToFactory(_order('a'), 'f1'), isTrue);
      expect(OrderService.isVisibleToFactory(_order('a'), 'f2'), isFalse);
      expect(
        OrderService.isVisibleToFactory(
          _order('a', status: OrderStatus.placed),
          'f1',
        ),
        isFalse,
      );
      expect(
        OrderService.isVisibleToFactory(_order('a', factoryId: null), 'f1'),
        isFalse,
      );
    });

    test('a factory may only start and finish production', () {
      expect(
        OrderService.factoryNextStatus(_order('a')),
        OrderStatus.inProduction,
      );
      expect(
        OrderService.factoryNextStatus(
          _order('a', status: OrderStatus.inProduction),
        ),
        OrderStatus.qualityCheck,
      );
      expect(
        OrderService.factoryNextStatus(
          _order('a', status: OrderStatus.qualityCheck),
        ),
        isNull,
      );
      expect(
        OrderService.factoryNextStatus(
          _order('a', status: OrderStatus.delivered),
        ),
        isNull,
      );
    });
  });

  group('FactoryOrderFilter', () {
    test('groups orders by status', () {
      expect(
        FactoryOrderFilter.allActive.matches(
          _order('a', status: OrderStatus.outForDelivery),
        ),
        isTrue,
      );
      expect(
        FactoryOrderFilter.allActive.matches(
          _order('a', status: OrderStatus.delivered),
        ),
        isFalse,
      );
      expect(FactoryOrderFilter.toStart.matches(_order('a')), isTrue);
      expect(
        FactoryOrderFilter.cancelled.matches(
          _order('a', status: OrderStatus.cancelled),
        ),
        isTrue,
      );
    });
  });

  group('OrderService.changeStatusAsFactory', () {
    late Directory temp;
    late OrderStorage storage;
    late OrderService service;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('factory_portal_test');
      storage = OrderStorage(
        fileProvider: () async => File('${temp.path}/orders.json'),
      );
      service = OrderService(orderStorage: storage);
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('starts and finishes production for its own order', () async {
      await storage.add(_order('CF-1'));

      final Order started = await service.changeStatusAsFactory(
        'CF-1',
        'f1',
        OrderStatus.inProduction,
      );
      expect(started.status, OrderStatus.inProduction);

      final Order finished = await service.changeStatusAsFactory(
        'CF-1',
        'f1',
        OrderStatus.qualityCheck,
      );
      expect(finished.status, OrderStatus.qualityCheck);
    });

    test('another factory cannot change the order', () async {
      await storage.add(_order('CF-1'));

      await expectLater(
        service.changeStatusAsFactory('CF-1', 'f2', OrderStatus.inProduction),
        throwsStateError,
      );
      expect((await service.findOrder('CF-1'))!.status, OrderStatus.confirmed);
    });

    test('a factory cannot skip a step', () async {
      await storage.add(_order('CF-1'));

      await expectLater(
        service.changeStatusAsFactory('CF-1', 'f1', OrderStatus.qualityCheck),
        throwsStateError,
      );
    });

    test('an order that is not confirmed yet is off limits', () async {
      await storage.add(_order('CF-1', status: OrderStatus.placed));

      await expectLater(
        service.changeStatusAsFactory('CF-1', 'f1', OrderStatus.inProduction),
        throwsStateError,
      );
    });

    test('after quality check the factory has no more moves', () async {
      await storage.add(_order('CF-1', status: OrderStatus.qualityCheck));

      await expectLater(
        service.changeStatusAsFactory(
          'CF-1',
          'f1',
          OrderStatus.outForDelivery,
        ),
        throwsStateError,
      );
    });

    test('an unknown order is refused', () async {
      await expectLater(
        service.changeStatusAsFactory('missing', 'f1', OrderStatus.inProduction),
        throwsStateError,
      );
    });
  });

  group('FactorySessionStorage', () {
    late Directory temp;
    late File file;
    late FactorySessionStorage storage;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('factory_session_test');
      file = File('${temp.path}/factory_session.json');
      storage = FactorySessionStorage(fileProvider: () async => file);
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('remembers and clears the chosen factory', () async {
      expect(await storage.readFactoryId(), isNull);

      await storage.saveFactoryId('f1');
      expect(await storage.readFactoryId(), 'f1');

      await storage.saveFactoryId(null);
      expect(await storage.readFactoryId(), isNull);
    });

    test('an unreadable file is ignored', () async {
      await file.writeAsString('not json');
      expect(await storage.readFactoryId(), isNull);
    });
  });
}
