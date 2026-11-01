import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/core/utils/date_formatters.dart';
import 'package:custom_factory_app/features/cart/models/cart_item.dart';
import 'package:custom_factory_app/features/orders/data/order_service.dart';
import 'package:custom_factory_app/features/orders/data/order_storage.dart';
import 'package:custom_factory_app/features/orders/models/delivery_address.dart';
import 'package:custom_factory_app/features/orders/models/order.dart';
import 'package:custom_factory_app/features/orders/models/order_display.dart';
import 'package:custom_factory_app/features/orders/models/payment_method.dart';
import 'package:custom_factory_app/features/orders/widgets/order_status_timeline.dart';

Order _order(String id, {OrderStatus status = OrderStatus.placed}) {
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
  );
}

void main() {
  late Directory temp;
  late File ordersFile;
  late OrderStorage storage;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('orders_tracking_test');
    ordersFile = File('${temp.path}/orders.json');
    storage = OrderStorage(fileProvider: () async => ordersFile);
  });

  tearDown(() async {
    await temp.delete(recursive: true);
  });

  group('DateFormatters', () {
    test('formats the date', () {
      expect(DateFormatters.dayMonthYear(DateTime(2026, 11, 1)), '1 Nov 2026');
    });

    test('formats afternoon, midnight and noon times', () {
      expect(
        DateFormatters.dateTime(DateTime(2026, 11, 1, 15, 5)),
        '1 Nov 2026, 3:05 PM',
      );
      expect(
        DateFormatters.dateTime(DateTime(2026, 11, 1, 0, 7)),
        '1 Nov 2026, 12:07 AM',
      );
      expect(
        DateFormatters.dateTime(DateTime(2026, 11, 1, 12)),
        '1 Nov 2026, 12:00 PM',
      );
    });
  });

  group('OrderDisplay', () {
    test('summarises the items and the total', () {
      final Order order = _order('CF-1');
      expect(order.itemsSummary, 'Mug x 2');
      expect(order.totalText, '৳200');
    });
  });

  group('OrderStorage.updateStatus', () {
    test('changes only the matching order', () async {
      await storage.add(_order('CF-1'));
      await storage.add(_order('CF-2'));

      final bool changed =
          await storage.updateStatus('CF-1', OrderStatus.confirmed);

      expect(changed, isTrue);
      final Map<String, Order> byId = <String, Order>{
        for (final Order order in await storage.read()) order.id: order,
      };
      expect(byId['CF-1']!.status, OrderStatus.confirmed);
      expect(byId['CF-2']!.status, OrderStatus.placed);
    });

    test('returns false for an unknown order', () async {
      await storage.add(_order('CF-1'));
      expect(await storage.updateStatus('missing', OrderStatus.cancelled), isFalse);
    });

    test('keeps entries this version cannot read', () async {
      await ordersFile.writeAsString(
        jsonEncode(<Object?>[
          <String, Object?>{'id': 'future-format'},
        ]),
      );
      await storage.add(_order('CF-1'));

      await storage.updateStatus('CF-1', OrderStatus.cancelled);

      final List<dynamic> raw =
          jsonDecode(await ordersFile.readAsString()) as List<dynamic>;
      expect(raw.length, 2);
      expect(raw.last, <String, Object?>{'id': 'future-format'});
    });

    test('leaves a corrupt file untouched', () async {
      await ordersFile.writeAsString('not json');

      await expectLater(
        storage.updateStatus('CF-1', OrderStatus.cancelled),
        throwsFormatException,
      );
      expect(await ordersFile.readAsString(), 'not json');
    });
  });

  group('OrderService cancel', () {
    test('cancels a newly placed order', () async {
      await storage.add(_order('CF-1'));
      final OrderService service = OrderService(orderStorage: storage);

      await service.cancelOrder('CF-1');

      expect((await service.findOrder('CF-1'))!.status, OrderStatus.cancelled);
    });

    test('refuses once the order is confirmed', () async {
      await storage.add(_order('CF-1', status: OrderStatus.confirmed));
      final OrderService service = OrderService(orderStorage: storage);

      await expectLater(service.cancelOrder('CF-1'), throwsStateError);
      expect((await service.findOrder('CF-1'))!.status, OrderStatus.confirmed);
    });

    test('refuses an unknown order', () async {
      final OrderService service = OrderService(orderStorage: storage);
      await expectLater(service.cancelOrder('missing'), throwsStateError);
    });

    test('only a placed order can be cancelled', () {
      expect(OrderService.canCancel(_order('CF-1')), isTrue);
      expect(
        OrderService.canCancel(_order('CF-1', status: OrderStatus.delivered)),
        isFalse,
      );
    });
  });

  group('OrderStatusTimeline', () {
    testWidgets('shows every step for an active order', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: OrderStatusTimeline(status: OrderStatus.inProduction),
            ),
          ),
        ),
      );

      for (final OrderStatus step in OrderStatus.values) {
        if (step == OrderStatus.cancelled) continue;
        expect(find.text(step.label), findsOneWidget, reason: step.label);
      }
      expect(find.text('This order was cancelled'), findsNothing);
    });

    testWidgets('shows a banner for a cancelled order', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: OrderStatusTimeline(status: OrderStatus.cancelled),
          ),
        ),
      );

      expect(find.text('This order was cancelled'), findsOneWidget);
      expect(find.text(OrderStatus.placed.label), findsNothing);
    });
  });
}
