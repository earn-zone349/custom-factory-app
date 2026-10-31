import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/editor/design_controller.dart';
import 'package:custom_factory_app/features/editor/models/design_element.dart';

void main() {
  group('DesignController', () {
    test('adds text and selects it', () {
      final DesignController controller = DesignController();
      expect(controller.addText('Hello'), isTrue);
      expect(controller.elements.length, 1);
      expect(controller.selected, isA<TextElement>());
    });

    test('rejects empty text', () {
      final DesignController controller = DesignController();
      expect(controller.addText('   '), isFalse);
      expect(controller.elements, isEmpty);
    });

    test('undo and redo restore elements', () {
      final DesignController controller = DesignController()
        ..addShape(ShapeKind.circle);
      expect(controller.elements.length, 1);

      controller.undo();
      expect(controller.elements, isEmpty);

      controller.redo();
      expect(controller.elements.length, 1);
    });

    test('delete removes the selected element', () {
      final DesignController controller = DesignController()
        ..addText('Delete me');
      controller.deleteSelected();
      expect(controller.elements, isEmpty);
      expect(controller.selectedId, isNull);
    });

    test('a drag gesture is recorded as one history step', () {
      final DesignController controller = DesignController()
        ..addText('Move me');
      final String id = controller.selectedId!;
      final double startX = controller.selected!.x;

      controller.beginTransform();
      controller.transformLive(id, dx: 10);
      controller.transformLive(id, dx: 10);
      controller.endTransform();
      expect(controller.selected!.x, startX + 20);

      controller.undo();
      expect(controller.selected!.x, startX);
    });
  });
}
