import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/admin/data/orders_csv.dart';
import 'package:custom_factory_app/features/admin/models/report_period.dart';
import 'package:custom_factory_app/features/admin/models/sales_report.dart';
import 'package:custom_factory_app/features/cart/models/cart_item.dart';
import 'package:custom_factory_app/features/orders/models/delivery_address.dart';
import 'package:custom_factory_app/features/orders/models/order.dart';
import 'package:custom_factory_app/features/orders/models/payment_method.dart';

final DateTime _now = DateTime(2026, 11, 10, 15);

Order _order(
  String id, {
  required DateTime createdAt,
  OrderStatus status = OrderStatus.placed,
  String category = 'Mug',
  int quantity = 2,
  double unitPrice = 100,
  String? factoryId,
  String? factoryName,
  String customer = 'Rahim Uddin',
}) {
  return Order(
    id: id,
    createdAt: createdAt,
    items: <CartItem>[
      CartItem(
        id: 'item_$id',
        category: category,
        colorName: 'Red',
        colorValue: 0xFFDC2626,
        quantity: quantity,
        unitPrice: unitPrice,
      ),
    ],
    address: DeliveryAddress(
      fullName: customer,
      phone: '01712345678',
      district: 'Dhaka',
      area: 'Mirpur',
      addressLine: 'House 5, Road 3, Block C',
    ),
    paymentMethod: PaymentMethod.cashOnDelivery,
    status: status,
    manufacturerId: factoryId,
    manufacturerName: factoryName,
  );
}

List<Order> _sampleOrders() {
  return <Order>[
    _order('o1', createdAt: DateTime(2026, 11, 10, 9)),
    _order(
      'o2',
      createdAt: DateTime(2026, 11, 9, 10),
      status: OrderStatus.delivered,
      category: 'T-Shirt',
      quantity: 3,
      unitPrice: 50,
      factoryId: 'f1',
      factoryName: 'Alpha',
    ),
    _order(
      'o3',
      createdAt: DateTime(2026, 11, 8, 10),
      status: OrderStatus.cancelled,
      quantity: 5,
    ),
    _order(
      'o4',
      createdAt: DateTime(2026, 11, 8, 11),
      status: OrderStatus.confirmed,
      quantity: 1,
      unitPrice: 0,
    ),
    _order(
      'o5',
      createdAt: DateTime(2026, 11, 7, 10),
      status: OrderStatus.inProduction,
      quantity: 4,
      factoryId: 'f1',
      factoryName: 'Alpha',
    ),
  ];
}

void main() {
  group('ReportPeriod', () {
    test('computes where each period starts', () {
      expect(ReportPeriod.today.startFrom(_now), DateTime(2026, 11, 10));
      expect(ReportPeriod.last7Days.startFrom(_now), DateTime(2026, 11, 4));
      expect(ReportPeriod.last30Days.startFrom(_now), DateTime(2026, 10, 12));
      expect(ReportPeriod.allTime.startFrom(_now), isNull);
    });

    test('filters orders by their local date', () {
      final List<Order> orders = <Order>[
        _order('today', createdAt: DateTime(2026, 11, 10, 9)),
        _order('edge7', createdAt: DateTime(2026, 11, 4)),
        _order('before7', createdAt: DateTime(2026, 11, 3, 23, 59)),
        _order('before30', createdAt: DateTime(2026, 10, 11, 12)),
      ];

      List<String> ids(ReportPeriod period) => period
          .filter(orders, _now)
          .map((Order order) => order.id)
          .toList();

      expect(ids(ReportPeriod.today), <String>['today']);
      expect(ids(ReportPeriod.last7Days), <String>['today', 'edge7']);
      expect(
        ids(ReportPeriod.last30Days),
        <String>['today', 'edge7', 'before7'],
      );
      expect(ids(ReportPeriod.allTime).length, 4);
    });
  });

  group('SalesReport', () {
    test('adds up the numbers and leaves cancelled orders out of sales', () {
      final SalesReport report = SalesReport.build(
        _sampleOrders(),
        period: ReportPeriod.allTime,
        now: _now,
      );

      expect(report.periodOrders.length, 5);
      expect(report.activeOrders, 4);
      expect(report.cancelledOrders, 1);
      expect(report.deliveredOrders, 1);
      expect(report.totalPieces, 10);
      expect(report.estimatedRevenue, 750);
      expect(report.deliveredRevenue, 150);
      expect(report.averageOrderValue, 250);
      expect(report.hasUnpricedOrders, isTrue);
      expect(report.cancellationRate, closeTo(0.2, 0.0001));
      expect(report.waitingForFactory, 2);
    });

    test('counts every status, including empty ones', () {
      final SalesReport report = SalesReport.build(
        _sampleOrders(),
        period: ReportPeriod.allTime,
        now: _now,
      );

      expect(report.statusCounts.length, OrderStatus.values.length);
      expect(report.statusCounts[OrderStatus.placed], 1);
      expect(report.statusCounts[OrderStatus.cancelled], 1);
      expect(report.statusCounts[OrderStatus.qualityCheck], 0);
    });

    test('ranks products and factories', () {
      final SalesReport report = SalesReport.build(
        _sampleOrders(),
        period: ReportPeriod.allTime,
        now: _now,
      );

      expect(report.products.first.category, 'Mug');
      expect(report.products.first.pieces, 7);
      expect(report.products.first.value, 600);
      expect(report.products.first.orders, 3);
      expect(report.products.last.category, 'T-Shirt');

      expect(report.factories.single.name, 'Alpha');
      expect(report.factories.single.orders, 2);
      expect(report.factories.single.pieces, 7);
    });

    test('an empty period gives zeros and never divides by zero', () {
      final SalesReport report = SalesReport.build(
        <Order>[],
        period: ReportPeriod.last7Days,
        now: _now,
      );

      expect(report.activeOrders, 0);
      expect(report.averageOrderValue, 0);
      expect(report.cancellationRate, 0);
      expect(report.products, isEmpty);
    });

    test('the daily chart covers seven days, oldest first', () {
      final SalesReport report = SalesReport.build(
        _sampleOrders(),
        period: ReportPeriod.last7Days,
        now: _now,
      );

      expect(report.timeline.length, 7);
      expect(report.timeline.first.label, '4 Nov');
      expect(report.timeline.last.label, '10 Nov');
      expect(
        report.timeline.map((TimelineBucket b) => b.orders).toList(),
        <int>[0, 0, 0, 1, 1, 1, 1],
      );
      expect(report.timeline[3].value, 400);
    });

    test('the monthly chart starts at the first order month', () {
      final List<Order> orders = <Order>[
        _order('a', createdAt: DateTime(2026, 9, 3)),
        _order('b', createdAt: DateTime(2026, 9, 20)),
        _order('c', createdAt: DateTime(2026, 10, 5)),
        _order('d', createdAt: DateTime(2026, 11, 2)),
      ];

      final SalesReport report = SalesReport.build(
        orders,
        period: ReportPeriod.allTime,
        now: _now,
      );

      expect(
        report.timeline.map((TimelineBucket b) => b.label).toList(),
        <String>['Sep 26', 'Oct 26', 'Nov 26'],
      );
      expect(
        report.timeline.map((TimelineBucket b) => b.orders).toList(),
        <int>[2, 1, 1],
      );
    });

    test('the monthly chart never shows more than twelve months', () {
      final SalesReport report = SalesReport.build(
        <Order>[
          _order('old', createdAt: DateTime(2025, 1, 5)),
          _order('new', createdAt: DateTime(2026, 11, 2)),
        ],
        period: ReportPeriod.allTime,
        now: _now,
      );

      expect(report.timeline.length, 12);
      expect(report.timeline.first.label, 'Dec 25');
      expect(report.timeline.last.orders, 1);
    });

    test('today has no chart', () {
      final SalesReport report = SalesReport.build(
        _sampleOrders(),
        period: ReportPeriod.today,
        now: _now,
      );

      expect(report.timeline, isEmpty);
      expect(report.periodOrders.length, 1);
    });
  });

  group('OrdersCsv', () {
    test('quotes values that contain commas, quotes or new lines', () {
      expect(OrdersCsv.escape('plain'), 'plain');
      expect(OrdersCsv.escape('a,b'), '"a,b"');
      expect(OrdersCsv.escape('say "hi"'), '"say ""hi"""');
      expect(OrdersCsv.escape('line1\nline2'), '"line1\nline2"');
    });

    test('defuses text that spreadsheets would run as a formula', () {
      expect(OrdersCsv.escape('=SUM(A1)'), "'=SUM(A1)");
      expect(OrdersCsv.escape('+1'), "'+1");
      expect(OrdersCsv.escape('-5'), "'-5");
      expect(OrdersCsv.escape('@user'), "'@user");
      expect(OrdersCsv.escape(''), '');
    });

    test('builds a header and one row per order', () {
      final String csv = OrdersCsv.build(<Order>[
        _order('CF-1', createdAt: DateTime(2026, 11, 10, 9, 5)),
        _order(
          'CF-2',
          createdAt: DateTime(2026, 11, 9, 10),
          customer: 'Rahim, "Raj"',
          factoryId: 'f1',
          factoryName: 'Alpha',
        ),
      ]);

      expect(csv.startsWith('\uFEFFOrder number,Date,Status'), isTrue);
      final List<String> lines = csv.split('\r\n');
      expect(lines.length, 4);
      expect(lines[1], startsWith('CF-1,2026-11-10 09:05,Order placed,'));
      expect(lines[2], contains('"Rahim, ""Raj"""'));
      expect(lines[2], contains(',Alpha,'));
      expect(lines.last, isEmpty);
    });
  });
}
