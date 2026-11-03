import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/admin/models/report_period.dart';
import 'package:custom_factory_app/features/cart/models/cart_item.dart';
import 'package:custom_factory_app/features/factory_portal/data/factory_orders_csv.dart';
import 'package:custom_factory_app/features/factory_portal/models/factory_report.dart';
import 'package:custom_factory_app/features/notes/models/order_note.dart';
import 'package:custom_factory_app/features/orders/models/delivery_address.dart';
import 'package:custom_factory_app/features/orders/models/order.dart';
import 'package:custom_factory_app/features/orders/models/payment_method.dart';

final DateTime _now = DateTime(2026, 11, 10, 15);
int _noteCounter = 0;

Order _order(
  String id, {
  OrderStatus status = OrderStatus.confirmed,
  String category = 'Mug',
  int quantity = 2,
  String? factoryId = 'f1',
  DateTime? createdAt,
}) {
  return Order(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 11, 9, 10),
    items: <CartItem>[
      CartItem(
        id: 'item_$id',
        category: category,
        style: 'Ceramic',
        size: '11 oz',
        colorName: 'Red',
        colorValue: 0xFFDC2626,
        quantity: quantity,
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

OrderNote _note(
  String orderId,
  NoteKind kind, {
  NoteAuthor author = NoteAuthor.manufacturer,
  String authorName = 'Alpha',
  int? days,
  bool resolved = false,
}) {
  return OrderNote(
    id: 'note_${_noteCounter++}',
    orderId: orderId,
    author: author,
    authorName: authorName,
    kind: kind,
    text: 'Text',
    createdAt: DateTime.utc(2026, 11, 9, 12),
    delayDays: kind == NoteKind.delay ? days : null,
    isResolved: resolved,
  );
}

FactoryReport _report(
  List<Order> orders, {
  List<OrderNote> notes = const <OrderNote>[],
  ReportPeriod period = ReportPeriod.allTime,
}) {
  return FactoryReport.build(
    orders: orders,
    notes: notes,
    factoryId: 'f1',
    period: period,
    now: _now,
  );
}

List<Order> _sampleOrders() {
  return <Order>[
    _order('o1'),
    _order('o2', status: OrderStatus.inProduction, quantity: 3),
    _order('o3', status: OrderStatus.qualityCheck, quantity: 4, category: 'Cap'),
    _order('o4', status: OrderStatus.delivered, quantity: 5, category: 'Cap'),
    _order('o5', status: OrderStatus.cancelled, quantity: 7),
    _order('o6', factoryId: 'f2'),
    _order('o7', status: OrderStatus.placed),
  ];
}

void main() {
  group('FactoryReport numbers', () {
    test('counts only the confirmed orders of this factory', () {
      final FactoryReport report = _report(_sampleOrders());

      expect(report.orders.map((Order o) => o.id).toList(), <String>[
        'o1',
        'o2',
        'o3',
        'o4',
        'o5',
      ]);
    });

    test('adds up orders and pieces, leaving cancelled orders out', () {
      final FactoryReport report = _report(_sampleOrders());

      expect(report.activeOrders, 4);
      expect(report.cancelledOrders, 1);
      expect(report.totalPieces, 14);
      expect(report.piecesToMake, 5);
      expect(report.piecesFinished, 9);
      expect(report.finishedOrders, 2);
      expect(report.deliveredOrders, 1);
      expect(report.completionRate, closeTo(0.5, 0.0001));
      expect(report.statusCounts[OrderStatus.cancelled], 1);
      expect(report.statusCounts[OrderStatus.qualityCheck], 1);
    });

    test('ranks products by pieces', () {
      final FactoryReport report = _report(_sampleOrders());

      expect(report.products.first.category, 'Cap');
      expect(report.products.first.pieces, 9);
      expect(report.products.first.orders, 2);
      expect(report.products.last.category, 'Mug');
      expect(report.products.last.pieces, 5);
    });

    test('an empty report gives zeros and never divides by zero', () {
      final FactoryReport report = _report(const <Order>[]);

      expect(report.activeOrders, 0);
      expect(report.totalPieces, 0);
      expect(report.completionRate, 0);
      expect(report.delayedOrderRate, 0);
      expect(report.averageDelayDays, 0);
      expect(report.products, isEmpty);
    });

    test('the period keeps only orders placed in it', () {
      final List<Order> orders = <Order>[
        _order('today', createdAt: DateTime(2026, 11, 10, 9)),
        _order('old', createdAt: DateTime(2026, 10, 1, 9)),
      ];

      expect(
        _report(orders, period: ReportPeriod.today)
            .orders
            .map((Order o) => o.id)
            .toList(),
        <String>['today'],
      );
      expect(_report(orders, period: ReportPeriod.last30Days).orders.length, 1);
      expect(_report(orders, period: ReportPeriod.allTime).orders.length, 2);
    });

    test('the daily chart covers seven days', () {
      final FactoryReport report = _report(
        _sampleOrders(),
        period: ReportPeriod.last7Days,
      );

      expect(report.timeline.length, 7);
    });
  });

  group('FactoryReport delays and problems', () {
    test('counts only notes this factory wrote for its active orders', () {
      final FactoryReport report = _report(
        _sampleOrders(),
        notes: <OrderNote>[
          _note('o2', NoteKind.delay, days: 3),
          _note('o2', NoteKind.delay, days: 5, resolved: true),
          _note('o3', NoteKind.problem),
          // Not counted: written by the admin team.
          _note(
            'o2',
            NoteKind.delay,
            days: 9,
            author: NoteAuthor.admin,
            authorName: 'Admin',
          ),
          // Not counted: the order is cancelled.
          _note('o5', NoteKind.delay, days: 4),
          // Not counted: written by a different factory.
          _note('o2', NoteKind.delay, days: 8, authorName: 'Beta'),
          // Not counted: the order belongs to another factory.
          _note('o6', NoteKind.problem),
          // Not counted: a plain note is not a delay or a problem.
          _note('o1', NoteKind.message),
        ],
      );

      expect(report.delayReports, 2);
      expect(report.delayDaysTotal, 8);
      expect(report.averageDelayDays, closeTo(4, 0.0001));
      expect(report.longestDelayDays, 5);
      expect(report.openDelays, 1);
      expect(report.delayedOrders, 1);
      expect(report.delayedOrderRate, closeTo(0.25, 0.0001));
      expect(report.problemReports, 1);
      expect(report.openProblems, 1);
      expect(report.openIssues, 2);
    });

    test('a report without notes has no delays', () {
      final FactoryReport report = _report(_sampleOrders());

      expect(report.delayReports, 0);
      expect(report.delayedOrders, 0);
      expect(report.openIssues, 0);
    });
  });

  group('FactoryOrdersCsv', () {
    test('lists the orders without customer details or prices', () {
      final String csv = FactoryOrdersCsv.build(<Order>[
        _order('CF-1', quantity: 10),
      ]);

      expect(
        csv.startsWith('\uFEFFOrder number,Date,Status,Items,Pieces'),
        isTrue,
      );
      final List<String> lines = csv.split('\r\n');
      expect(lines.length, 3);
      expect(lines[1], startsWith('CF-1,'));
      expect(lines[1], contains('Mug (Ceramic · Red · 11 oz) x 10'));
      expect(lines[1], endsWith(',10'));

      for (final String secret in const <String>[
        'Rahim',
        '01712345678',
        'Mirpur',
        'Dhaka',
        'Phone',
        'Price',
      ]) {
        expect(csv.contains(secret), isFalse, reason: secret);
      }
    });

    test('quotes values that contain commas', () {
      final String csv = FactoryOrdersCsv.build(<Order>[_order('CF-1')]);

      // The date has a comma, so it must be quoted.
      expect(csv.split('\r\n')[1], contains('"9 Nov 2026, 10:00 AM"'));
    });
  });
}
