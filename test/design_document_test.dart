import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/editor/data/design_document.dart';
import 'package:custom_factory_app/features/editor/data/design_exporter.dart';
import 'package:custom_factory_app/features/editor/data/design_storage.dart';
import 'package:custom_factory_app/features/editor/models/design_element.dart';

DesignDocument _sampleDocument() {
  return DesignDocument(
    category: 'Mug',
    baseColorValue: 0xFF16A34A,
    elements: <DesignElement>[
      const TextElement(
        id: 'a',
        x: 10,
        y: 20,
        scale: 1.5,
        rotation: 0.5,
        text: 'Hi',
        color: Color(0xFF123456),
        bold: true,
      ),
      const ShapeElement(
        id: 'b',
        x: 30,
        y: 40,
        kind: ShapeKind.star,
        width: 80,
        height: 90,
      ),
      ImageElement(
        id: 'c',
        x: 50,
        y: 60,
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        width: 100,
        height: 50,
      ),
    ],
  );
}

void main() {
  group('DesignDocument', () {
    test('survives a JSON round trip', () {
      final DesignDocument restored =
          DesignDocument.fromJson(_sampleDocument().toJson());

      expect(restored.category, 'Mug');
      expect(restored.baseColorValue, 0xFF16A34A);
      expect(restored.elements.length, 3);

      final TextElement text = restored.elements[0] as TextElement;
      expect(text.text, 'Hi');
      expect(text.bold, isTrue);
      expect(text.scale, 1.5);
      expect(text.color.toARGB32(), 0xFF123456);

      final ShapeElement shape = restored.elements[1] as ShapeElement;
      expect(shape.kind, ShapeKind.star);
      expect(shape.width, 80);

      final ImageElement image = restored.elements[2] as ImageElement;
      expect(image.bytes, <int>[1, 2, 3]);
    });

    test('rejects invalid data', () {
      expect(() => DesignDocument.fromJson('not json'), throwsFormatException);
      expect(
        () => DesignDocument.fromJson('{"version":1}'),
        throwsFormatException,
      );
    });
  });

  group('DesignStorage', () {
    late Directory temp;
    late DesignStorage storage;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('designs_test');
      storage = DesignStorage(rootProvider: () async => temp);
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('saves, lists, loads and deletes a design', () async {
      final String id = await storage.save(_sampleDocument());

      expect(await storage.listIds(), contains(id));
      final DesignDocument loaded = await storage.load(id);
      expect(loaded.category, 'Mug');

      await storage.delete(id);
      expect(await storage.listIds(), isEmpty);
    });

    test('rejects unsafe ids', () async {
      await expectLater(storage.load('../secret'), throwsArgumentError);
    });
  });

  group('DesignExporter', () {
    testWidgets('renders a PNG of the canvas size', (
      WidgetTester tester,
    ) async {
      await tester.runAsync(() async {
        const ShapeElement shape = ShapeElement(
          id: 's',
          x: 180,
          y: 210,
          kind: ShapeKind.circle,
        );
        final Uint8List png =
            await DesignExporter.renderPng(<DesignElement>[shape], scale: 1);

        expect(png.sublist(0, 4), <int>[0x89, 0x50, 0x4E, 0x47]);
        final ui.Codec codec = await ui.instantiateImageCodec(png);
        final ui.FrameInfo frame = await codec.getNextFrame();
        expect(frame.image.width, 360);
        expect(frame.image.height, 420);
        frame.image.dispose();
        codec.dispose();

        // An exported PNG can itself be placed back as an image element.
        final Uint8List second = await DesignExporter.renderPng(
          <DesignElement>[
            ImageElement(
              id: 'i',
              x: 180,
              y: 210,
              bytes: png,
              width: 120,
              height: 140,
            ),
          ],
          scale: 1,
        );
        expect(second, isNotEmpty);
      });
    });

    test('refuses to export an empty design', () async {
      await expectLater(
        DesignExporter.renderPng(<DesignElement>[]),
        throwsA(isA<DesignExportException>()),
      );
    });
  });
}
