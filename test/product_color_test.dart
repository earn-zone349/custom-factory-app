import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:custom_factory_app/features/customize/models/category_config.dart';
import 'package:custom_factory_app/features/editor/design_controller.dart';
import 'package:custom_factory_app/features/editor/models/design_element.dart';

void main() {
  group('Product colors', () {
    test('offers 20 to 25 unique colors', () {
      final int count = CategoryConfig.colors.length;
      expect(count, inInclusiveRange(20, 25));

      final Set<String> names =
          CategoryConfig.colors.map((ColorOption c) => c.name).toSet();
      final Set<int> values = CategoryConfig.colors
          .map((ColorOption c) => c.value.toARGB32())
          .toSet();
      expect(names.length, count);
      expect(values.length, count);
    });

    test('keeps the original first six colors in order', () {
      const List<String> original = <String>[
        'White',
        'Black',
        'Red',
        'Blue',
        'Green',
        'Yellow',
      ];
      final List<String> actual = CategoryConfig.colors
          .take(6)
          .map((ColorOption c) => c.name)
          .toList();
      expect(actual, original);
    });
  });

  group('DesignController product color', () {
    test('flags text that is hard to see on the product color', () {
      final DesignController controller = DesignController()
        ..addText('Hello');

      expect(controller.hasLowContrastWith(Colors.black), isTrue);
      expect(controller.hasLowContrastWith(Colors.white), isFalse);
    });

    test('default text color can follow the product color', () {
      final DesignController controller = DesignController()
        ..defaultTextColor = Colors.white
        ..addText('Light');

      expect((controller.selected! as TextElement).color, Colors.white);
    });
  });
}
