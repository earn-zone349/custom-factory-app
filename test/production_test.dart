import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/cart/models/cart_item.dart';
import 'package:custom_factory_app/features/editor/data/design_document.dart';
import 'package:custom_factory_app/features/editor/data/design_storage.dart';
import 'package:custom_factory_app/features/editor/models/design_element.dart';
import 'package:custom_factory_app/features/orders/models/delivery_address.dart';
import 'package:custom_factory_app/features/orders/models/order.dart';
import 'package:custom_factory_app/features/orders/models/payment_method.dart';
import 'package:custom_factory_app/features/production/models/print_file_exception.dart';
import 'package:custom_factory_app/features/production/models/production_sheet_page.dart';
import 'package:custom_factory_app/features/production/production_files_service.dart';
import 'package:custom_factory_app/features/production/production_sheet_pdf.dart';
import 'package:custom_factory_app/features/production/production_sheet_renderer.dart';

CartItem _item(
  String id, {
  String category = 'Mug',
  String? designId,
  int quantity = 10,
}) {
  return CartItem(
    id: id,
    category: category,
    style: 'Ceramic',
    size: '11 oz',
    colorName: 'Red',
    colorValue: 0xFFDC2626,
    quantity: quantity,
    unitPrice: 100,
    notes: 'Please keep the logo centered',
    designId: designId,
  );
}

Order _order(String id, List<CartItem> items) {
  return Order(
    id: id,
    createdAt: DateTime.utc(2026, 11, 1, 10),
    items: items,
    address: const DeliveryAddress(
      fullName: 'Rahim Uddin',
      phone: '01712345678',
      district: 'Dhaka',
      area: 'Mirpur',
      addressLine: 'House 5, Road 3, Block C',
    ),
    paymentMethod: PaymentMethod.cashOnDelivery,
    manufacturerId: 'f1',
    manufacturerName: 'Alpha Print House',
  );
}

DesignDocument _design() {
  return const DesignDocument(
    category: 'Mug',
    baseColorValue: 0xFFDC2626,
    elements: <DesignElement>[
      ShapeElement(id: 's', x: 180, y: 210, kind: ShapeKind.circle),
    ],
  );
}

/// Runs [body] with real file access and a service that uses temp folders.
Future<void> _withService(
  WidgetTester tester,
  Future<void> Function(ProductionFilesService service, DesignStorage storage)
      body,
) async {
  await tester.runAsync(() async {
    final Directory root =
        await Directory.systemTemp.createTemp('production_test');
    try {
      final Directory designs = await Directory('${root.path}/designs').create();
      final Directory output = await Directory('${root.path}/out').create();
      final DesignStorage storage =
          DesignStorage(rootProvider: () async => designs);
      final ProductionFilesService service = ProductionFilesService(
        storage: storage,
        tempDirectory: () async => output,
      );
      await body(service, storage);
    } finally {
      await root.delete(recursive: true);
    }
  });
}

Future<(int, int)> _pngSize(Uint8List bytes) async {
  final ui.Codec codec = await ui.instantiateImageCodec(bytes);
  final ui.FrameInfo frame = await codec.getNextFrame();
  final (int, int) size = (frame.image.width, frame.image.height);
  frame.image.dispose();
  codec.dispose();
  return size;
}

void main() {
  group('file names', () {
    test('use the order number, item number and product', () {
      final Order order = _order('CF-1', <CartItem>[
        _item('a', category: 'Shopping Bag'),
        _item('b', category: 'ব্যাগ'),
      ]);

      expect(ProductionFilesService.fileName(order, 0), 'CF-1_1_shopping-bag.png');
      expect(ProductionFilesService.fileName(order, 1), 'CF-1_2_item.png');
    });

    test('never contain unsafe characters', () {
      final Order order = _order('CF/../1 x', <CartItem>[_item('a')]);

      expect(
        ProductionFilesService.fileName(order, 0),
        matches(RegExp(r'^[A-Za-z0-9_.-]+$')),
      );
    });
  });

  group('ProductionFilesService', () {
    testWidgets('creates a print-ready PNG for an item', (
      WidgetTester tester,
    ) async {
      await _withService(tester, (
        ProductionFilesService service,
        DesignStorage storage,
      ) async {
        final String designId = await storage.save(_design());
        final Order order =
            _order('CF-1', <CartItem>[_item('a', designId: designId)]);

        final File file = await service.createPrintFile(order, 0);

        expect(file.path, endsWith('CF-1_1_mug.png'));
        final Uint8List bytes = await file.readAsBytes();
        expect(bytes.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
        expect(await _pngSize(bytes), (1440, 1680));
      });
    });

    testWidgets('creates one print file per item', (WidgetTester tester) async {
      await _withService(tester, (
        ProductionFilesService service,
        DesignStorage storage,
      ) async {
        final String designId = await storage.save(_design());
        final Order order = _order('CF-1', <CartItem>[
          _item('a', designId: designId),
          _item('b', category: 'Cap', designId: designId),
        ]);

        final List<File> files = await service.createAllPrintFiles(order);

        expect(files.length, 2);
        expect(files[0].path, endsWith('CF-1_1_mug.png'));
        expect(files[1].path, endsWith('CF-1_2_cap.png'));
      });
    });

    testWidgets('refuses items without a design or with a missing design', (
      WidgetTester tester,
    ) async {
      await _withService(tester, (
        ProductionFilesService service,
        DesignStorage storage,
      ) async {
        final Order noDesign = _order('CF-1', <CartItem>[_item('a')]);
        final Order missing =
            _order('CF-2', <CartItem>[_item('a', designId: 'missing')]);

        await expectLater(
          service.createPrintFile(noDesign, 0),
          throwsA(isA<PrintFileException>()),
        );
        await expectLater(
          service.createPrintFile(missing, 0),
          throwsA(isA<PrintFileException>()),
        );
      });
    });

    testWidgets('creates a production sheet even if one design is missing', (
      WidgetTester tester,
    ) async {
      await _withService(tester, (
        ProductionFilesService service,
        DesignStorage storage,
      ) async {
        final String designId = await storage.save(_design());
        final Order order = _order('CF-1', <CartItem>[
          _item('a', designId: designId),
          _item('b', category: 'Cap'),
        ]);

        final File file = await service.createProductionSheet(order);

        expect(file.path, endsWith('CF-1_production_sheet.pdf'));
        final Uint8List bytes = await file.readAsBytes();
        expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
        expect(bytes.length, greaterThan(1000));
      });
    });

    testWidgets('refuses a production sheet for an order without items', (
      WidgetTester tester,
    ) async {
      await _withService(tester, (
        ProductionFilesService service,
        DesignStorage storage,
      ) async {
        await expectLater(
          service.createProductionSheet(_order('CF-1', <CartItem>[])),
          throwsA(isA<PrintFileException>()),
        );
      });
    });
  });

  group('production sheet pages', () {
    testWidgets('a page has A4 proportions, also with very long text', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        final Uint8List png = await ProductionSheetRenderer.renderPng(
          ProductionSheetPage(
            orderId: 'CF-1',
            orderDate: '1 Nov 2026',
            factoryName: 'A very long factory name ' * 10,
            itemNumber: 1,
            itemCount: 2,
            category: 'Shopping Bag with a very long product name ' * 4,
            style: 'Cloth Tote',
            size: 'Large',
            colorName: 'Mint',
            colorValue: 0xFFA7F3D0,
            quantity: 1000000,
            notes: 'Note ' * 200,
          ),
        );

        expect(await _pngSize(png), (1240, 1754));
      });
    });

    testWidgets('pages are combined into one PDF', (WidgetTester tester) async {
      await tester.runAsync(() async {
        final Uint8List page = await ProductionSheetRenderer.renderPng(
          const ProductionSheetPage(
            orderId: 'CF-1',
            orderDate: '1 Nov 2026',
            factoryName: 'Alpha',
            itemNumber: 1,
            itemCount: 1,
            category: 'Mug',
            colorName: 'Red',
            colorValue: 0xFFDC2626,
            quantity: 10,
          ),
        );

        final Uint8List pdf = await ProductionSheetPdf.build(<Uint8List>[page]);

        expect(String.fromCharCodes(pdf.sublist(0, 5)), '%PDF-');
      });
    });

    test('a PDF needs at least one page', () async {
      await expectLater(
        ProductionSheetPdf.build(<Uint8List>[]),
        throwsArgumentError,
      );
    });
  });
}
