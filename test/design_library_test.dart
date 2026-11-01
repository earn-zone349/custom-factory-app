import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/editor/data/design_document.dart';
import 'package:custom_factory_app/features/editor/data/design_library.dart';
import 'package:custom_factory_app/features/editor/data/design_storage.dart';
import 'package:custom_factory_app/features/editor/design_controller.dart';
import 'package:custom_factory_app/features/editor/models/design_element.dart';

void main() {
  group('DesignLibrary', () {
    test('loads saved designs and skips corrupt files', () async {
      final Directory temp =
          await Directory.systemTemp.createTemp('library_test');
      addTearDown(() => temp.delete(recursive: true));
      final DesignStorage storage = DesignStorage(rootProvider: () async => temp);

      const DesignDocument document = DesignDocument(
        category: 'Mug',
        baseColorValue: 0xFF16A34A,
        elements: <DesignElement>[
          TextElement(id: 'a', x: 10, y: 10, text: 'Hi'),
        ],
      );
      final String id = await storage.save(document);
      await File('${temp.path}/broken.json').writeAsString('not json');

      final List<SavedDesign> designs =
          await DesignLibrary(storage: storage).loadAll();

      expect(designs.length, 1);
      expect(designs.first.id, id);
      expect(designs.first.document.category, 'Mug');
      expect(designs.first.createdAt, isNotNull);
    });
  });

  group('DesignController saved designs', () {
    test('loadElements keeps ids, skips history and avoids id clashes', () {
      final DesignController controller = DesignController()
        ..loadElements(const <DesignElement>[
          TextElement(id: 'element_0', x: 1, y: 1, text: 'A'),
          TextElement(id: 'element_1', x: 2, y: 2, text: 'B'),
        ]);

      expect(controller.canUndo, isFalse);
      expect(controller.elements.length, 2);

      controller.addText('C');
      final Set<String> ids =
          controller.elements.map((DesignElement e) => e.id).toSet();
      expect(ids.length, 3);
    });

    test('matches detects unsaved changes and undo restores the match', () {
      final DesignController controller = DesignController()
        ..addText('Saved');
      final List<DesignElement> saved = controller.elements;
      expect(controller.matches(saved), isTrue);

      controller.addShape(ShapeKind.circle);
      expect(controller.matches(saved), isFalse);

      controller.undo();
      expect(controller.matches(saved), isTrue);
    });
  });
}
