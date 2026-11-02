import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/cart/models/cart_item.dart';
import 'package:custom_factory_app/features/notes/data/note_service.dart';
import 'package:custom_factory_app/features/notes/data/note_storage.dart';
import 'package:custom_factory_app/features/notes/models/order_note.dart';
import 'package:custom_factory_app/features/orders/models/delivery_address.dart';
import 'package:custom_factory_app/features/orders/models/order.dart';
import 'package:custom_factory_app/features/orders/models/payment_method.dart';

Order _order(
  String id, {
  OrderStatus status = OrderStatus.inProduction,
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
  group('OrderNote', () {
    test('survives a map round trip', () {
      final OrderNote note = OrderNote(
        id: 'n1',
        orderId: 'CF-1',
        author: NoteAuthor.manufacturer,
        authorName: 'Alpha',
        kind: NoteKind.delay,
        text: 'মেশিন নষ্ট',
        createdAt: DateTime.utc(2026, 11, 1, 10),
        delayDays: 3,
      );

      final OrderNote restored = OrderNote.fromMap(note.toMap());

      expect(restored.text, 'মেশিন নষ্ট');
      expect(restored.delayDays, 3);
      expect(restored.author, NoteAuthor.manufacturer);
      expect(restored.isOpenIssue, isTrue);
    });

    test('a delay needs a valid number of days', () {
      final Map<String, dynamic> map = <String, dynamic>{
        'id': 'n1',
        'orderId': 'CF-1',
        'author': 'manufacturer',
        'authorName': 'Alpha',
        'kind': 'delay',
        'text': 'Late',
        'createdAt': '2026-11-01T10:00:00.000Z',
        'delayDays': 99,
        'isResolved': false,
      };

      expect(() => OrderNote.fromMap(map), throwsFormatException);
    });

    test('rejects incomplete data', () {
      expect(
        () => OrderNote.fromMap(<String, dynamic>{'id': 'x'}),
        throwsFormatException,
      );
    });

    test('only unresolved delays and problems are open issues', () {
      OrderNote note(NoteKind kind, {bool resolved = false}) {
        return OrderNote(
          id: 'n',
          orderId: 'CF-1',
          author: NoteAuthor.admin,
          authorName: 'Admin',
          kind: kind,
          text: 'Text',
          createdAt: DateTime.utc(2026, 11, 1),
          delayDays: kind == NoteKind.delay ? 2 : null,
          isResolved: resolved,
        );
      }

      expect(note(NoteKind.message).isOpenIssue, isFalse);
      expect(note(NoteKind.problem).isOpenIssue, isTrue);
      expect(note(NoteKind.delay, resolved: true).isOpenIssue, isFalse);
    });
  });

  group('NoteService', () {
    late Directory temp;
    late File file;
    late NoteStorage storage;
    late NoteService service;
    DateTime now = DateTime.utc(2026, 11, 1, 10);

    setUp(() async {
      now = DateTime.utc(2026, 11, 1, 10);
      temp = await Directory.systemTemp.createTemp('notes_test');
      file = File('${temp.path}/order_notes.json');
      storage = NoteStorage(fileProvider: () async => file);
      service = NoteService(storage: storage, clock: () => now);
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('a factory can report a delay on its own active order', () async {
      final OrderNote note = await service.addAsManufacturer(
        order: _order('CF-1'),
        factoryId: 'f1',
        kind: NoteKind.delay,
        text: '  Machine broke  ',
        delayDays: 3,
      );

      expect(note.authorName, 'Alpha');
      expect(note.text, 'Machine broke');
      final List<OrderNote> saved = await service.listForOrder('CF-1');
      expect(saved.single.delayDays, 3);
    });

    test('another factory cannot add a note', () async {
      await expectLater(
        service.addAsManufacturer(
          order: _order('CF-1'),
          factoryId: 'f2',
          kind: NoteKind.message,
          text: 'Hello',
        ),
        throwsStateError,
      );
      expect(await service.listAll(), isEmpty);
    });

    test('a finished order is read only for the factory', () async {
      for (final OrderStatus status in const <OrderStatus>[
        OrderStatus.delivered,
        OrderStatus.cancelled,
        OrderStatus.placed,
      ]) {
        await expectLater(
          service.addAsManufacturer(
            order: _order('CF-1', status: status),
            factoryId: 'f1',
            kind: NoteKind.message,
            text: 'Hello',
          ),
          throwsStateError,
          reason: status.name,
        );
      }

      final OrderNote reply = await service.addAsAdmin(
        order: _order('CF-1', status: OrderStatus.delivered),
        text: 'Thank you',
      );
      expect(reply.author, NoteAuthor.admin);
      expect(reply.authorName, 'Admin');
    });

    test('rejects invalid text and delays', () async {
      final Order order = _order('CF-1');

      Future<OrderNote> add(NoteKind kind, String text, {int? days}) {
        return service.addAsManufacturer(
          order: order,
          factoryId: 'f1',
          kind: kind,
          text: text,
          delayDays: days,
        );
      }

      await expectLater(add(NoteKind.message, ' '), throwsArgumentError);
      await expectLater(add(NoteKind.message, 'a' * 501), throwsArgumentError);
      await expectLater(add(NoteKind.delay, 'Late'), throwsArgumentError);
      await expectLater(
        add(NoteKind.delay, 'Late', days: 31),
        throwsArgumentError,
      );
      await expectLater(
        add(NoteKind.problem, 'Broken', days: 2),
        throwsArgumentError,
      );
      expect(await service.listAll(), isEmpty);
    });

    test('resolving closes an issue', () async {
      final Order order = _order('CF-1');
      final OrderNote issue = await service.addAsManufacturer(
        order: order,
        factoryId: 'f1',
        kind: NoteKind.problem,
        text: 'Wrong color',
      );

      expect(
        NoteService.openIssuesFor(<Order>[order], await service.listAll()),
        hasLength(1),
      );

      now = DateTime.utc(2026, 11, 2, 9);
      await service.resolve(issue.id);

      final OrderNote saved = (await service.listForOrder('CF-1')).single;
      expect(saved.isResolved, isTrue);
      expect(saved.resolvedAt, DateTime.utc(2026, 11, 2, 9));
      expect(
        NoteService.openIssuesFor(<Order>[order], await service.listAll()),
        isEmpty,
      );
      await expectLater(service.resolve('missing'), throwsStateError);
    });

    test('open issues skip cancelled orders and list the newest first', () async {
      final Order active = _order('CF-1');
      final Order cancelled = _order('CF-2', status: OrderStatus.cancelled);

      Future<void> report(Order order, String text) {
        return service.addAsManufacturer(
          order: _order(order.id),
          factoryId: 'f1',
          kind: NoteKind.problem,
          text: text,
        );
      }

      await report(active, 'First');
      now = DateTime.utc(2026, 11, 1, 11);
      await report(cancelled, 'On a cancelled order');
      now = DateTime.utc(2026, 11, 1, 12);
      await report(active, 'Second');

      final List<OrderNote> open = NoteService.openIssuesFor(
        <Order>[active, cancelled],
        await service.listAll(),
      );

      expect(open.map((OrderNote n) => n.text).toList(), <String>['Second', 'First']);
    });

    test('notes of different orders stay separate, oldest first', () async {
      await service.addAsAdmin(order: _order('CF-1'), text: 'One');
      await service.addAsAdmin(order: _order('CF-2'), text: 'Other order');
      await service.addAsAdmin(order: _order('CF-1'), text: 'Two');

      final List<OrderNote> notes = await service.listForOrder('CF-1');

      expect(notes.map((OrderNote n) => n.text).toList(), <String>['One', 'Two']);
    });

    test('an order cannot have more than the allowed number of notes', () async {
      final Order order = _order('CF-1');
      for (int i = 0; i < NoteRules.maxNotesPerOrder; i++) {
        await service.addAsAdmin(order: order, text: 'Note $i');
      }

      await expectLater(
        service.addAsAdmin(order: order, text: 'One too many'),
        throwsStateError,
      );
    });

    test('a corrupt notes file is backed up and a new one is started', () async {
      await file.writeAsString('not json');

      await service.addAsAdmin(order: _order('CF-1'), text: 'Hello');

      expect(await service.listAll(), hasLength(1));
      expect(await File('${file.path}.corrupt').exists(), isTrue);
    });

    test('keeps entries this version cannot read', () async {
      await file.writeAsString(
        jsonEncode(<Object?>[
          <String, Object?>{'id': 'future-format'},
        ]),
      );

      await service.addAsAdmin(order: _order('CF-1'), text: 'Hello');

      final List<dynamic> raw =
          jsonDecode(await file.readAsString()) as List<dynamic>;
      expect(raw.length, 2);
      expect(await service.listAll(), hasLength(1));
    });

    test('resolving leaves a corrupt file untouched', () async {
      await file.writeAsString('not json');

      await expectLater(service.resolve('n1'), throwsFormatException);
      expect(await file.readAsString(), 'not json');
    });
  });
}
