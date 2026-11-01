import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/admin/models/order_stats.dart';
import 'package:custom_factory_app/features/cart/models/cart_item.dart';
import 'package:custom_factory_app/features/orders/data/order_service.dart';
import 'package:custom_factory_app/features/orders/data/order_storage.dart';
import 'package:custom_factory_app/features/orders/models/delivery_address.dart';
import 'package:custom_factory_app/features/orders/models/order.dart';
import 'package:custom_factory_app/features/orders/models/order_workflow.dart';
import 'package:custom_factory_app/features/orders/models/payment_method.dart';

Order _order(
  String id, {
  OrderStatus status = OrderStatus.placed,
  double unitPrice = 100,
}) {
  return Order(
    id: id,
    createdAt: DateTime.utc(2026, 11, 1, 10),
    items: <CartItem>[
      CartItem(
        id: 'a',
        category: 'Mug',
        colorName: 'Red',
        colorValue: 0xFFDC2626,
        quantity: 2,
        unitPrice: unitPrice,
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
  group('OrderWorkflow', () {
    test('the normal path moves forward one step at a time', () {
      const List<OrderStatus> path = <OrderStatus>[
        OrderStatus.placed,
        OrderStatus.confirmed,
        OrderStatus.inProduction,
        OrderStatus.qualityCheck,
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
      ];
      for (int i = 0; i < path.length - 1; i++) {
        expect(OrderWorkflow.nextOptions(path[i]).first, path[i + 1]);
      }
    });

    test('finished orders have no next status', () {
      expect(OrderWorkflow.nextOptions(OrderStatus.delivered), isEmpty);
      expect(OrderWorkflow.nextOptions(OrderStatus.cancelled), isEmpty);
    });

    test('cancelling is allowed only before production starts', () {
      expect(
        OrderWorkflow.canMove(OrderStatus.placed, OrderStatus.cancelled),
        isTrue,
      );
      expect(
        OrderWorkflow.canMove(OrderStatus.confirmed, OrderStatus.cancelled),
        isTrue,
      );
      expect(
        OrderWorkflow.canMove(OrderStatus.inProduction, OrderStatus.cancelled),
        isFalse,
      );
    });

    test('steps cannot be skipped', () {
      expect(
        OrderWorkflow.canMove(OrderStatus.placed, OrderStatus.delivered),
        isFalse,
      );
    });

    test('a failed quality check can go back to production', () {
      expect(
        OrderWorkflow.canMove(
          OrderStatus.qualityCheck,
          OrderStatus.inProduction,
        ),
        isTrue,
      );
      expect(
        OrderWorkflow.actionLabel(
          OrderStatus.qualityCheck,
          OrderStatus.inProduction,
        ),
        contains('back to production'),
      );
    });
  });

  group('OrderStats', () {
    test('counts orders by group and adds up the value', () {
      final OrderStats stats = OrderStats.from(<Order>[
        _order('CF-1'),
        _order('CF-2', unitPrice: 0),
        _order('CF-3', status: OrderStatus.confirmed),
        _order('CF-4', status: OrderStatus.delivered),
        _order('CF-5', status: OrderStatus.cancelled),
      ]);

      expect(stats.total, 5);
      expect(stats.newOrders, 2);
      expect(stats.inProgress, 1);
      expect(stats.delivered, 1);
      expect(stats.cancelled, 1);
      expect(stats.activeValue, 600);
      expect(stats.hasUnpricedOrders, isTrue);
    });

    test('is empty when there are no orders', () {
      final OrderStats stats = OrderStats.from(<Order>[]);
      expect(stats.total, 0);
      expect(stats.activeValue, 0);
      expect(stats.hasUnpricedOrders, isFalse);
    });
  });

  group('OrderService.changeStatus', () {
    late Directory temp;
    late OrderStorage storage;
    late OrderService service;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('admin_test');
      storage = OrderStorage(
        fileProvider: () async => File('${temp.path}/orders.json'),
      );
      service = OrderService(orderStorage: storage);
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('moves an order through the whole flow', () async {
      await storage.add(_order('CF-1'));

      for (final OrderStatus step in const <OrderStatus>[
        OrderStatus.confirmed,
        OrderStatus.inProduction,
        OrderStatus.qualityCheck,
        OrderStatus.outForDelivery,
        OrderStatus.delivered,
      ]) {
        final Order updated = await service.changeStatus('CF-1', step);
        expect(updated.status, step);
      }
      expect(
        (await service.findOrder('CF-1'))!.status,
        OrderStatus.delivered,
      );
    });

    test('refuses to skip a step', () async {
      await storage.add(_order('CF-1'));

      await expectLater(
        service.changeStatus('CF-1', OrderStatus.delivered),
        throwsStateError,
      );
      expect((await service.findOrder('CF-1'))!.status, OrderStatus.placed);
    });

    test('a cancelled order cannot be changed', () async {
      await storage.add(_order('CF-1', status: OrderStatus.cancelled));

      await expectLater(
        service.changeStatus('CF-1', OrderStatus.confirmed),
        throwsStateError,
      );
    });

    test('refuses an unknown order', () async {
      await expectLater(
        service.changeStatus('missing', OrderStatus.confirmed),
        throwsStateError,
      );
    });

    test('a confirmed order can no longer be cancelled by the customer',
        () async {
      await storage.add(_order('CF-1'));
      await service.changeStatus('CF-1', OrderStatus.confirmed);

      await expectLater(service.cancelOrder('CF-1'), throwsStateError);
    });
  });
}
