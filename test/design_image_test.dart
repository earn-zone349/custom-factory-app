import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/editor/design_controller.dart';
import 'package:custom_factory_app/features/editor/models/design_element.dart';

void main() {
  group('DesignController images', () {
    test('adds a wide image sized to the canvas', () {
      final DesignController controller = DesignController();
      final bool added = controller.addImage(base64Decode('AAEC'), 2);

      expect(added, isTrue);
      final ImageElement image = controller.selected! as ImageElement;
      expect(image.width, 200);
      expect(image.height, 100);
    });

    test('rejects invalid image data', () {
      final DesignController controller = DesignController();

      expect(controller.addImage(base64Decode('AAEC'), 0), isFalse);
      expect(controller.addImage(base64Decode(''), 1), isFalse);
      expect(controller.elements, isEmpty);
    });
  });
}
